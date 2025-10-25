import {
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
  useLocation,
  useState,
} from '@remix-run/react';
import type { ReactNode } from 'react';
import './styles/tailwind.css';

export const meta = () => [
  { charset: 'utf-8' },
  { name: 'viewport', content: 'width=device-width,initial-scale=1' },
  { name: 'description', content: 'Singularity HITL Control Panel' },
];

export default function App() {
  const location = useLocation();
  const [activeTab, setActiveTab] = useState<'dashboard' | 'approvals' | 'status'>('dashboard');

  // Update active tab based on location
  if (location.pathname === '/approvals' && activeTab !== 'approvals') {
    setActiveTab('approvals');
  } else if (location.pathname === '/status' && activeTab !== 'status') {
    setActiveTab('status');
  } else if ((location.pathname === '/' || location.pathname === '') && activeTab !== 'dashboard') {
    setActiveTab('dashboard');
  }

  return (
    <html lang="en">
      <head>
        <Meta />
        <Links />
      </head>
      <body className="bg-gray-950 text-gray-100">
        {/* Navigation */}
        <nav className="border-b border-gray-800 bg-gray-900 px-6 py-4">
          <div className="max-w-7xl mx-auto flex items-center justify-between">
            <div className="flex items-center gap-8">
              <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
                🔮 Singularity Control Panel
              </h1>
              <div className="flex gap-4">
                <a
                  href="/"
                  className={`px-4 py-2 rounded-lg transition-colors ${
                    activeTab === 'dashboard'
                      ? 'bg-blue-600 text-white'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Dashboard
                </a>
                <a
                  href="/approvals"
                  className={`px-4 py-2 rounded-lg transition-colors ${
                    activeTab === 'approvals'
                      ? 'bg-blue-600 text-white'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Approvals & Questions
                </a>
                <a
                  href="/status"
                  className={`px-4 py-2 rounded-lg transition-colors ${
                    activeTab === 'status'
                      ? 'bg-blue-600 text-white'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  System Status
                </a>
              </div>
            </div>
          </div>
        </nav>

        {/* Content */}
        <div className="max-w-7xl mx-auto p-6">
          <Outlet />
        </div>

        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}
