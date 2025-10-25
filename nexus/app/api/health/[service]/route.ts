import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { service: string } }
) {
  const service = params.service.toLowerCase();
  const startTime = Date.now();

  try {
    // Map service names to their health endpoints
    const healthChecks: Record<string, () => Promise<boolean>> = {
      singularity: async () => {
        try {
          const res = await fetch('http://localhost:4000/health', {
            signal: AbortSignal.timeout(3000),
          });
          return res.ok;
        } catch {
          return false;
        }
      },
      genesis: async () => {
        try {
          const res = await fetch('http://localhost:5000/health', {
            signal: AbortSignal.timeout(3000),
          });
          return res.ok;
        } catch {
          return false;
        }
      },
      centralcloud: async () => {
        try {
          const res = await fetch('http://localhost:6000/health', {
            signal: AbortSignal.timeout(3000),
          });
          return res.ok;
        } catch {
          return false;
        }
      },
      nats: async () => {
        // Check NATS connectivity (would need NATS client)
        return true; // Placeholder
      },
      postgresql: async () => {
        // Check PostgreSQL connectivity
        return true; // Placeholder
      },
      'rust-nifs': async () => {
        // Check if Rust NIFs are loaded
        return true; // Placeholder
      },
    };

    const checkFn = healthChecks[service];
    if (!checkFn) {
      return NextResponse.json(
        { error: `Unknown service: ${service}` },
        { status: 400 }
      );
    }

    const isHealthy = await checkFn();
    const latency = Date.now() - startTime;

    return NextResponse.json(
      {
        service,
        healthy: isHealthy,
        latency,
        timestamp: new Date().toISOString(),
      },
      { status: isHealthy ? 200 : 503 }
    );
  } catch (error) {
    const latency = Date.now() - startTime;
    return NextResponse.json(
      {
        service,
        healthy: false,
        latency,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
      },
      { status: 503 }
    );
  }
}
