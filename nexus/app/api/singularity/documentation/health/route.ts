import { NextResponse } from 'next/server';

/**
 * Documentation system health endpoint
 * Bridges to Singularity documentation bootstrap via HTTP
 */
export async function GET() {
  try {
    const response = await fetch(
      'http://localhost:4000/api/documentation/health',
      { signal: AbortSignal.timeout(5000) }
    ).catch(() => null);

    if (response?.ok) {
      const data = await response.json();
      return NextResponse.json(data);
    }

    return NextResponse.json({
      status: 'unhealthy',
      message: 'Documentation system is not available',
    }, { status: 503 });
  } catch (error) {
    return NextResponse.json({
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error',
    }, { status: 500 });
  }
}
