#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}          # dev | test | prod
PROJECT_NAME=${2:-twin}

echo "🚀 Deploying ${PROJECT_NAME} to ${ENVIRONMENT}..."

# 1. Build Lambda package
cd "$(dirname "$0")/.."        # project root
echo "📦 Building Lambda package..."
(cd backend && uv run deploy.py)

# 2. Terraform workspace & apply
cd terraform
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
STATE_BUCKET="twin-terraform-state-${AWS_ACCOUNT_ID}"
LOCKS_TABLE="twin-terraform-locks"

# Ensure S3 state bucket exists (use if exists, create if not)
echo "🔍 Checking S3 state bucket: $STATE_BUCKET..."
if ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  echo "🪣 State bucket $STATE_BUCKET not found. Creating a new one..."
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION"
  else
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
  aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  echo "✅ S3 state bucket created."
else
  echo "✅ S3 state bucket $STATE_BUCKET exists. Using it."
fi

# Ensure DynamoDB locks table exists (use if exists, create if not)
if ! aws dynamodb describe-table --table-name "$LOCKS_TABLE" --region "$AWS_REGION" 2>/dev/null; then
  echo "🔒 Creating DynamoDB table for Terraform locking: $LOCKS_TABLE..."
  aws dynamodb create-table \
    --table-name "$LOCKS_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"
  aws dynamodb wait table-exists --table-name "$LOCKS_TABLE" --region "$AWS_REGION"
  echo "✅ DynamoDB lock table created."
fi

# Clear any stale DynamoDB checksum / lock if state object does not exist in S3
WORKSPACE_KEY="env:/${ENVIRONMENT}/${ENVIRONMENT}/terraform.tfstate"
if ! aws s3api head-object --bucket "$STATE_BUCKET" --key "$WORKSPACE_KEY" 2>/dev/null; then
  echo "🧹 State file $WORKSPACE_KEY not found in S3. Clearing any stale lock entries in DynamoDB..."
  aws dynamodb delete-item --table-name "$LOCKS_TABLE" \
    --key "{\"LockID\": {\"S\": \"${STATE_BUCKET}/${WORKSPACE_KEY}-md5\"}}" 2>/dev/null || true
  aws dynamodb delete-item --table-name "$LOCKS_TABLE" \
    --key "{\"LockID\": {\"S\": \"${STATE_BUCKET}/${ENVIRONMENT}/terraform.tfstate-md5\"}}" 2>/dev/null || true
fi

terraform init -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${LOCKS_TABLE}" \
  -backend-config="encrypt=true"

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace new "$ENVIRONMENT"
else
  terraform workspace select "$ENVIRONMENT"
fi

# Clean up any orphaned AWS resources not tracked in Terraform state (prevents EntityAlreadyExists errors)
echo "🔍 Checking for untracked AWS resources that might conflict..."

# 1. IAM Role
if ! terraform state list 2>/dev/null | grep -q "aws_iam_role.lambda_role"; then
  ROLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-lambda-role"
  if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    echo "⚠️ Found untracked IAM role $ROLE_NAME. Cleaning it up..."
    for policy in $(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null); do
      aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy" 2>/dev/null || true
    done
    for inline in $(aws iam list-role-policies --role-name "$ROLE_NAME" --query "PolicyNames[]" --output text 2>/dev/null); do
      aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$inline" 2>/dev/null || true
    done
    aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true
    echo "✅ Removed untracked IAM role $ROLE_NAME"
  fi
fi

# 2. API Gateway
if ! terraform state list 2>/dev/null | grep -q "aws_apigatewayv2_api.main"; then
  API_NAME="${PROJECT_NAME}-${ENVIRONMENT}-api-gateway"
  for api_id in $(aws apigatewayv2 get-apis --query "Items[?Name=='$API_NAME'].ApiId" --output text 2>/dev/null); do
    if [ -n "$api_id" ] && [ "$api_id" != "None" ]; then
      echo "⚠️ Found untracked API Gateway $API_NAME ($api_id). Deleting..."
      aws apigatewayv2 delete-api --api-id "$api_id" 2>/dev/null || true
      echo "✅ Deleted API Gateway $api_id"
    fi
  done
fi

# 3. Lambda Function
if ! terraform state list 2>/dev/null | grep -q "aws_lambda_function.api"; then
  FN_NAME="${PROJECT_NAME}-${ENVIRONMENT}-api"
  if aws lambda get-function --function-name "$FN_NAME" 2>/dev/null; then
    echo "⚠️ Found untracked Lambda function $FN_NAME. Deleting..."
    aws lambda delete-function --function-name "$FN_NAME" 2>/dev/null || true
    echo "✅ Deleted Lambda function $FN_NAME"
  fi
fi

# Use prod.tfvars for production environment
if [ "$ENVIRONMENT" = "prod" ]; then
  TF_APPLY_CMD=(terraform apply -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
else
  TF_APPLY_CMD=(terraform apply -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
fi

echo "🎯 Applying Terraform..."
"${TF_APPLY_CMD[@]}"

API_URL=$(terraform output -raw api_gateway_url)
FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)
CUSTOM_URL=$(terraform output -raw custom_domain_url 2>/dev/null || true)

# 3. Build + deploy frontend
cd ../frontend

# Create production environment file with API URL
echo "📝 Setting API URL for production..."
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.production

npm install
npm run build
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete
cd ..

# 4. Final messages
echo -e "\n✅ Deployment complete!"
echo "🌐 CloudFront URL : $(terraform -chdir=terraform output -raw cloudfront_url)"
if [ -n "$CUSTOM_URL" ]; then
  echo "🔗 Custom domain  : $CUSTOM_URL"
fi
echo "📡 API Gateway    : $API_URL"