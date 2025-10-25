export default function DashboardRoute() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-white mb-2">Dashboard</h2>
        <p className="text-gray-400">System overview and metrics</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {/* System Status Card */}
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-blue-400 mb-4">System Status</h3>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-400">NATS Connection</span>
              <span className="text-green-400">✓ Connected</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Agents Running</span>
              <span className="text-green-400">6 Active</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Uptime</span>
              <span className="text-green-400">24h 32m</span>
            </div>
          </div>
        </div>

        {/* LLM Requests Card */}
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-blue-400 mb-4">LLM Requests</h3>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-400">Today</span>
              <span className="text-white">342</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">This Hour</span>
              <span className="text-white">28</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Avg Response</span>
              <span className="text-white">2.3s</span>
            </div>
          </div>
        </div>

        {/* HITL Requests Card */}
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-blue-400 mb-4">HITL Requests</h3>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-400">Pending</span>
              <span className="text-yellow-400">0</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Approved Today</span>
              <span className="text-green-400">12</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Avg Response Time</span>
              <span className="text-white">4m 23s</span>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-blue-400 mb-4">Recent Activity</h3>
        <div className="space-y-3">
          <div className="border-l-2 border-blue-500 pl-4 py-1">
            <p className="text-sm text-gray-300">
              <span className="font-semibold">Self-Improving Agent</span> submitted code refactoring
            </p>
            <p className="text-xs text-gray-500">2 minutes ago</p>
          </div>
          <div className="border-l-2 border-green-500 pl-4 py-1">
            <p className="text-sm text-gray-300">Code approval approved - changes applied to lib/analysis.ex</p>
            <p className="text-xs text-gray-500">15 minutes ago</p>
          </div>
          <div className="border-l-2 border-blue-500 pl-4 py-1">
            <p className="text-sm text-gray-300">
              <span className="font-semibold">Architecture Agent</span> requested human guidance on design decision
            </p>
            <p className="text-xs text-gray-500">1 hour ago</p>
          </div>
        </div>
      </div>
    </div>
  );
}
