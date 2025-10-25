export default function StatusRoute() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-white mb-2">System Status</h2>
        <p className="text-gray-400">Detailed health checks and system information</p>
      </div>

      {/* Singularity Status */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-blue-400 mb-4">Singularity</h3>
        <div className="space-y-3">
          <StatusItem label="Status" value="Healthy" color="green" />
          <StatusItem label="Uptime" value="24h 32m 15s" color="green" />
          <StatusItem label="Port" value="4000" color="gray" />
          <StatusItem label="Database" value="PostgreSQL 17 (Connected)" color="green" />
          <StatusItem label="NATS Connection" value="127.0.0.1:4222 (Connected)" color="green" />
          <StatusItem label="Memory Usage" value="245 MB / 2 GB" color="yellow" />
        </div>
      </div>

      {/* Nexus Bun Server (LLM Router) */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-cyan-400 mb-4">Nexus LLM Router (Bun)</h3>
        <div className="space-y-3">
          <StatusItem label="Status" value="Running" color="green" />
          <StatusItem label="Port" value="3001" color="gray" />
          <StatusItem label="NATS Subscriptions" value="llm.request (active)" color="green" />
          <StatusItem label="Requests (1h)" value="342" color="gray" />
          <StatusItem label="Error Rate" value="0.5%" color="yellow" />
          <StatusItem label="Avg Response" value="2.3s" color="green" />
        </div>
      </div>

      {/* Nexus Browser (HITL Control Panel) */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-purple-400 mb-4">Nexus HITL Control Panel (Remix)</h3>
        <div className="space-y-3">
          <StatusItem label="Status" value="Running" color="green" />
          <StatusItem label="Port" value="3000" color="gray" />
          <StatusItem label="WebSocket Bridge" value="/ws/approval (active)" color="green" />
          <StatusItem label="Connected Clients" value="1" color="green" />
          <StatusItem label="Pending Approvals" value="0" color="green" />
          <StatusItem label="Bundle Size" value="~85KB (Remix+React)" color="yellow" />
        </div>
      </div>

      {/* Agent Status */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-blue-400 mb-4">Active Agents</h3>
        <div className="space-y-3">
          <AgentStatus name="Self-Improving Agent" status="active" tasks={3} />
          <AgentStatus name="Architecture Agent" status="idle" tasks={0} />
          <AgentStatus name="Refactoring Agent" status="active" tasks={1} />
          <AgentStatus name="Technology Agent" status="idle" tasks={0} />
          <AgentStatus name="Cost-Optimized Agent" status="active" tasks={2} />
          <AgentStatus name="Chat Agent" status="idle" tasks={0} />
        </div>
      </div>

      {/* LLM Providers */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-blue-400 mb-4">LLM Providers</h3>
        <div className="space-y-3">
          <ProviderStatus name="Claude (Anthropic)" status="available" requests={142} />
          <ProviderStatus name="Gemini (Google)" status="available" requests={89} />
          <ProviderStatus name="OpenAI" status="unavailable" requests={0} />
          <ProviderStatus name="Copilot (GitHub)" status="available" requests={111} />
        </div>
      </div>
    </div>
  );
}

function StatusItem({
  label,
  value,
  color,
}: {
  label: string;
  value: string;
  color: 'green' | 'yellow' | 'red' | 'gray';
}) {
  const colorClass = {
    green: 'text-green-400',
    yellow: 'text-yellow-400',
    red: 'text-red-400',
    gray: 'text-gray-300',
  }[color];

  return (
    <div className="flex justify-between items-center">
      <span className="text-gray-400">{label}</span>
      <span className={`font-mono ${colorClass}`}>{value}</span>
    </div>
  );
}

function AgentStatus({
  name,
  status,
  tasks,
}: {
  name: string;
  status: 'active' | 'idle';
  tasks: number;
}) {
  const statusColor = status === 'active' ? 'text-green-400' : 'text-gray-400';

  return (
    <div className="flex justify-between items-center border-l-2 border-blue-500 pl-4">
      <span className="text-gray-300">{name}</span>
      <div className="flex gap-4">
        <span className={`text-sm ${statusColor}`}>{status.toUpperCase()}</span>
        <span className="text-gray-500 text-sm">{tasks} tasks</span>
      </div>
    </div>
  );
}

function ProviderStatus({
  name,
  status,
  requests,
}: {
  name: string;
  status: 'available' | 'unavailable';
  requests: number;
}) {
  const statusColor = status === 'available' ? 'text-green-400' : 'text-red-400';

  return (
    <div className="flex justify-between items-center border-l-2 border-cyan-500 pl-4">
      <span className="text-gray-300">{name}</span>
      <div className="flex gap-4">
        <span className={`text-sm ${statusColor}`}>{status.toUpperCase()}</span>
        <span className="text-gray-500 text-sm">{requests} requests (1h)</span>
      </div>
    </div>
  );
}
