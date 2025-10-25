'use client';

import { useEffect, useState } from 'react';

interface SystemInfo {
  system: string;
  status: string;
  agents?: number;
  mode?: string;
  error?: string;
}

export function Dashboard() {
  const [systems, setSystems] = useState<SystemInfo[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchSystemStatus = async () => {
      try {
        setLoading(true);
        const systemNames = ['singularity', 'genesis', 'centralcloud'];
        const responses = await Promise.allSettled(
          systemNames.map(sys =>
            fetch(`/api/system-status/${sys}`).then(r => r.json())
          )
        );

        const systemsData = responses.map((result, idx) => {
          if (result.status === 'fulfilled') {
            return result.value;
          }
          return {
            system: systemNames[idx],
            status: 'disconnected',
            error: 'Failed to fetch status'
          };
        });

        setSystems(systemsData as SystemInfo[]);
      } catch (error) {
        console.error('Failed to fetch system status:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchSystemStatus();
    const interval = setInterval(fetchSystemStatus, 5000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-400"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">System Overview</h2>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {systems.map((sys) => (
          <div
            key={sys.system}
            className="bg-gray-900 border border-gray-800 rounded-lg p-6 hover:border-blue-600 transition-colors"
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-semibold capitalize">{sys.system}</h3>
              <div
                className={`w-3 h-3 rounded-full ${
                  sys.status === 'online' ? 'bg-green-500' : 'bg-red-500'
                }`}
              ></div>
            </div>

            <div className="space-y-2 text-sm text-gray-400">
              <div>Status: <span className="text-gray-200">{sys.status}</span></div>
              {sys.mode && <div>Mode: <span className="text-gray-200">{sys.mode}</span></div>}
              {sys.agents && <div>Agents: <span className="text-gray-200">{sys.agents}</span></div>}
              {sys.error && <div className="text-red-400">Error: {sys.error}</div>}
            </div>

            <button className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white py-2 px-4 rounded-lg transition-colors">
              View Details
            </button>
          </div>
        ))}
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-xl font-semibold mb-4">Recent Activity</h3>
        <div className="space-y-3 text-sm text-gray-400">
          <div className="flex items-center gap-2">
            <span className="text-green-400">●</span>
            <span>Singularity LLM handler initialized</span>
            <span className="ml-auto text-xs">2m ago</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-green-400">●</span>
            <span>Code analysis completed</span>
            <span className="ml-auto text-xs">5m ago</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-blue-400">●</span>
            <span>NATS connection established</span>
            <span className="ml-auto text-xs">10m ago</span>
          </div>
        </div>
      </div>
    </div>
  );
}
