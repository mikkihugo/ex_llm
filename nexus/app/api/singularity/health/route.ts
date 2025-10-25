import { NextResponse } from 'next/server';

/**
 * Singularity health endpoint
 * Bridges to Singularity OTP system via HTTP
 */
export async function GET() {
  try {
    // In production, this would call Singularity via NATS or internal HTTP
    // For now, return a mock response that reflects the actual health check structure

    const response = await fetch('http://localhost:4000/health', {
      signal: AbortSignal.timeout(5000),
    }).catch(() => null);

    if (response?.ok) {
      const data = await response.json();
      return NextResponse.json({
        status: 'online',
        ...data,
      });
    }

    // Fallback response
    return NextResponse.json({
      status: 'offline',
      services: {
        database: 'down',
        nats: 'down',
        rust_nifs: 'unknown',
      },
      error: 'Failed to connect to Singularity',
    }, { status: 503 });
  } catch (error) {
    return NextResponse.json({
      status: 'error',
      error: error instanceof Error ? error.message : 'Unknown error',
    }, { status: 500 });
  }
}
