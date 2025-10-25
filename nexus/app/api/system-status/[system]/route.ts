import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { system: string } }
) {
  const system = params.system.toLowerCase();

  try {
    // Map system names to their respective endpoints
    // This would call the actual backend systems via NATS or HTTP
    const endpoints: Record<string, string> = {
      singularity: 'http://localhost:4000/health',
      genesis: 'http://localhost:5000/health',
      centralcloud: 'http://localhost:6000/health',
    };

    const endpoint = endpoints[system];
    if (!endpoint) {
      return NextResponse.json(
        { error: `Unknown system: ${system}` },
        { status: 400 }
      );
    }

    try {
      const response = await fetch(endpoint, {
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();

      return NextResponse.json({
        system,
        status: 'online',
        ...data,
      });
    } catch (error) {
      // System not available, return offline status
      return NextResponse.json({
        system,
        status: 'offline',
        error: error instanceof Error ? error.message : 'Connection failed',
      });
    }
  } catch (error) {
    return NextResponse.json(
      {
        error: 'Failed to check system status',
        details: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 500 }
    );
  }
}
