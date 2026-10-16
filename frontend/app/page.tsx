import Twin from '@/components/twin';
import { ExternalLink, Award, GraduationCap, FolderGit2, Cloud } from 'lucide-react';

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-slate-50 to-gray-100 py-8 px-4">
      <div className="container mx-auto max-w-4xl">
        {/* Profile / Intro Banner */}
        <div className="text-center mb-6">
          <h1 className="text-4xl font-extrabold text-gray-900 tracking-tight mb-2">
            Charan M <span className="text-slate-600 font-medium text-2xl">(Chiru)</span>
          </h1>
          <p className="text-base sm:text-lg text-gray-600 max-w-2xl mx-auto">
            Interactive AI Digital Twin representing Charan — exploring Large Language Models, Autonomous Agents, and Production AI.
          </p>

          {/* Highlights / Badges */}
          <div className="mt-4 flex flex-wrap justify-center gap-2.5">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-blue-50 text-blue-800 border border-blue-200">
              <GraduationCap className="w-3.5 h-3.5" />
              BCA Graduate (7.85 CGPA) · Pursuing MCA @ CMR College
            </span>
            <a
              href="https://github.com/Chiru144/Spotify-MCP-Web-MCP-Server"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-800 border border-emerald-200 hover:bg-emerald-100 transition"
            >
              <FolderGit2 className="w-3.5 h-3.5" />
              Hobby Project: Spotify-MCP-Web-MCP-Server
              <ExternalLink className="w-3 h-3" />
            </a>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-purple-50 text-purple-800 border border-purple-200">
              <Award className="w-3.5 h-3.5" />
              Ed Donner Certified: 6 AI Tracks
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-sky-50 text-sky-800 border border-sky-200">
              <Cloud className="w-3.5 h-3.5" />
              AWS (SageMaker AI, Bedrock, Serverless) · Azure · GCP · Vercel · Terraform
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-amber-50 text-amber-800 border border-amber-200">
              🎮 Gamer · 🏏 Cricket &amp; Virat Kohli · 🪙 Rare Coins
            </span>
          </div>
        </div>

        {/* Chat Application */}
        <div className="h-[620px] bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
          <Twin />
        </div>

        {/* Footer */}
        <footer className="mt-6 text-center text-xs text-gray-500 space-y-2">
          <p>
            Powered by Next.js, FastAPI, AWS (Bedrock, SageMaker AI, Lambda), Terraform &amp; Vercel · Personal AI Digital Twin of Charan M
          </p>
          <div className="flex justify-center gap-4 text-slate-600 pt-1">
            <a
              href="https://github.com/Chiru144"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-slate-900 underline inline-flex items-center gap-1"
            >
              GitHub <ExternalLink className="w-3 h-3" />
            </a>
            <a
              href="https://www.linkedin.com/in/charan-m-3829933ab/"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-slate-900 underline inline-flex items-center gap-1"
            >
              LinkedIn <ExternalLink className="w-3 h-3" />
            </a>
            <a
              href="https://github.com/Chiru144/Spotify-MCP-Web-MCP-Server"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-slate-900 underline inline-flex items-center gap-1"
            >
              Spotify MCP Repo <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </footer>
      </div>
    </main>
  );
}