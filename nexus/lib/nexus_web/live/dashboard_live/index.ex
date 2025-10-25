defmodule NexusWeb.DashboardLive.Index do
  use NexusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to NATS status updates
    if connected?(socket) do
      Nexus.NatsClient.subscribe_to_status()
    end

    {:ok,
     assign(socket,
       singularity: %{status: "connecting", agents: 0},
       genesis: %{status: "connecting", experiments: 0},
       centralcloud: %{status: "connecting", insights: 0},
       last_update: DateTime.utc_now()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <div class="systems-grid">
        <div class="system-card singularity">
          <div class="card-header">
            <h2>🧠 Singularity</h2>
            <span class={"status-badge " <> @singularity.status}><%= @singularity.status %></span>
          </div>
          <div class="card-body">
            <div class="stat">
              <span class="stat-label">Active Agents</span>
              <span class="stat-value"><%= @singularity.agents %></span>
            </div>
            <div class="stat">
              <span class="stat-label">Mode</span>
              <span class="stat-value">Autonomous OTP</span>
            </div>
          </div>
        </div>

        <div class="system-card genesis">
          <div class="card-header">
            <h2>🧪 Genesis</h2>
            <span class={"status-badge " <> @genesis.status}><%= @genesis.status %></span>
          </div>
          <div class="card-body">
            <div class="stat">
              <span class="stat-label">Experiments</span>
              <span class="stat-value"><%= @genesis.experiments %></span>
            </div>
            <div class="stat">
              <span class="stat-label">Mode</span>
              <span class="stat-value">Experimentation Engine</span>
            </div>
          </div>
        </div>

        <div class="system-card centralcloud">
          <div class="card-header">
            <h2>☁️ CentralCloud</h2>
            <span class={"status-badge " <> @centralcloud.status}><%= @centralcloud.status %></span>
          </div>
          <div class="card-body">
            <div class="stat">
              <span class="stat-label">Insights</span>
              <span class="stat-value"><%= @centralcloud.insights %></span>
            </div>
            <div class="stat">
              <span class="stat-label">Mode</span>
              <span class="stat-value">Learning Aggregation</span>
            </div>
          </div>
        </div>
      </div>

      <div class="info-section">
        <h3>System Architecture</h3>
        <p>
          Nexus is a unified control panel that connects to three autonomous backend systems via NATS messaging:
        </p>
        <ul>
          <li><strong>Singularity:</strong> Core AI agents & code analysis (pure OTP)</li>
          <li><strong>Genesis:</strong> Experimentation & sandboxing engine (pure OTP)</li>
          <li><strong>CentralCloud:</strong> Cross-instance learning & aggregation (pure OTP)</li>
        </ul>
      </div>

      <div class="footer">
        <small>Last updated: <%= @last_update %></small>
      </div>
    </div>

    <style>
      .dashboard { padding: 2rem 0; }
      .systems-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; margin-bottom: 3rem; }
      .system-card { border: 1px solid #334155; border-radius: 8px; padding: 1.5rem; background: #1e293b; }
      .system-card.singularity { border-left: 4px solid #8b5cf6; }
      .system-card.genesis { border-left: 4px solid #06b6d4; }
      .system-card.centralcloud { border-left: 4px solid #10b981; }
      .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
      .card-header h2 { font-size: 1.25rem; margin: 0; }
      .status-badge { padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.875rem; font-weight: 600; }
      .status-badge.online { background: #10b981; color: #000; }
      .status-badge.connecting { background: #f59e0b; color: #000; }
      .status-badge.offline { background: #ef4444; color: #fff; }
      .card-body { display: flex; flex-direction: column; gap: 1rem; }
      .stat { display: flex; justify-content: space-between; align-items: center; padding: 0.75rem 0; border-bottom: 1px solid #334155; }
      .stat:last-child { border-bottom: none; }
      .stat-label { color: #94a3b8; font-size: 0.875rem; }
      .stat-value { font-weight: 600; font-size: 1.125rem; }
      .info-section { background: #1e293b; border: 1px solid #334155; border-radius: 8px; padding: 1.5rem; margin-bottom: 2rem; }
      .info-section h3 { margin-top: 0; margin-bottom: 1rem; }
      .info-section ul { margin-left: 1.5rem; line-height: 1.6; }
      .footer { text-align: center; color: #64748b; padding-top: 1rem; border-top: 1px solid #334155; }
    </style>
    """
  end
end
