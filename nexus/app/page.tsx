'use client';

import { useState } from 'react';
import { Dashboard } from '@/components/dashboard';
import { ChatPanel } from '@/components/chat-panel';
import { SystemStatus } from '@/components/system-status';

export default function Home() {
  const [activeTab, setActiveTab] = useState<'dashboard' | 'chat' | 'status'>('dashboard');

  return (
    <main className="min-h-screen bg-gray-950">
      {/* Navigation */}
      <nav className="border-b border-gray-800 bg-gray-900 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-8">
            <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
              🔮 Singularity Control Panel
            </h1>
            <div className="flex gap-4">
              <button
                onClick={() => setActiveTab('dashboard')}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  activeTab === 'dashboard'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-400 hover:text-gray-200'
                }`}
              >
                Dashboard
              </button>
              <button
                onClick={() => setActiveTab('chat')}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  activeTab === 'chat'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-400 hover:text-gray-200'
                }`}
              >
                Chat
              </button>
              <button
                onClick={() => setActiveTab('status')}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  activeTab === 'status'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-400 hover:text-gray-200'
                }`}
              >
                System Status
              </button>
            </div>
          </div>
        </div>
      </nav>

      {/* Content */}
      <div className="max-w-7xl mx-auto p-6">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'chat' && <ChatPanel />}
        {activeTab === 'status' && <SystemStatus />}
      </div>
    </main>
  );
}
