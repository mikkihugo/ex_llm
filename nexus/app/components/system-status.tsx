'use client';

import { useEffect, useState } from 'react';

interface ServiceStatus {
  name: string;
  status: 'up' | 'down' | 'loading';
  latency?: number;
  lastCheck?: string;
}

export function SystemStatus() {
  const [services, setServices] = useState<ServiceStatus[]>([
    { name: 'Singularity', status: 'loading' },
    { name: 'Genesis', status: 'loading' },
    { name: 'CentralCloud', status: 'loading' },
    { name: 'NATS', status: 'loading' },
    { name: 'PostgreSQL', status: 'loading' },
    { name: 'Rust NIFs', status: 'loading' },
  ]);

  useEffect(() => {
    const checkServices = async () => {
      const newServices = await Promise.all(
        services.map(async (service) => {
          const startTime = Date.now();
          try {
            const response = await fetch(`/api/health/${service.name.toLowerCase()}`, {
              signal: AbortSignal.timeout(5000),
            });
            const latency = Date.now() - startTime;

            return {
              ...service,
              status: response.ok ? 'up' : 'down',
              latency,
              lastCheck: new Date().toLocaleTimeString(),
            };
          } catch (error) {
            return {
              ...service,
              status: 'down' as const,
              lastCheck: new Date().toLocaleTimeString(),
            };
          }
        })
      );

      setServices(newServices);
    };

    checkServices();
    const interval = setInterval(checkServices, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">System Health</h2>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {services.map((service) => (
          <div
            key={service.name}
            className="bg-gray-900 border border-gray-800 rounded-lg p-6"
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">{service.name}</h3>
              <div className="flex items-center gap-2">
                <div
                  className={`w-3 h-3 rounded-full ${
                    service.status === 'up'
                      ? 'bg-green-500'
                      : service.status === 'loading'
                        ? 'bg-yellow-500 animate-pulse'
                        : 'bg-red-500'
                  }`}
                ></div>
                <span className="text-sm text-gray-400">
                  {service.status === 'up'
                    ? 'Healthy'
                    : service.status === 'loading'
                      ? 'Checking...'
                      : 'Offline'}
                </span>
              </div>
            </div>

            <div className="space-y-2 text-sm text-gray-400">
              {service.latency && (
                <div>
                  Latency: <span className="text-green-400">{service.latency}ms</span>
                </div>
              )}
              {service.lastCheck && (
                <div>
                  Last check: <span className="text-gray-300">{service.lastCheck}</span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Metrics */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <h3 className="text-xl font-semibold mb-4">Performance Metrics</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-gray-800 rounded p-4">
            <div className="text-sm text-gray-400">Uptime</div>
            <div className="text-2xl font-bold text-green-400">99.9%</div>
          </div>
          <div className="bg-gray-800 rounded p-4">
            <div className="text-sm text-gray-400">Requests/s</div>
            <div className="text-2xl font-bold text-blue-400">1,234</div>
          </div>
          <div className="bg-gray-800 rounded p-4">
            <div className="text-sm text-gray-400">Avg Latency</div>
            <div className="text-2xl font-bold text-yellow-400">45ms</div>
          </div>
          <div className="bg-gray-800 rounded p-4">
            <div className="text-sm text-gray-400">Errors</div>
            <div className="text-2xl font-bold text-red-400">2</div>
          </div>
        </div>
      </div>
    </div>
  );
}
