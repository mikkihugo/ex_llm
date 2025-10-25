import { NextResponse } from 'next/server';

/**
 * Documentation system status endpoint
 * Bridges to Singularity documentation pipeline via HTTP
 */
export async function GET() {
  try {
    const response = await fetch(
      'http://localhost:4000/api/documentation/status',
      { signal: AbortSignal.timeout(5000) }
    ).catch(() => null);

    if (response?.ok) {
      const data = await response.json();
      return NextResponse.json(data);
    }

    return NextResponse.json({
      pipeline: {
        status: 'unknown',
        running: false,
      },
      quality: {
        status: 'unknown',
      },
      error: 'Failed to fetch documentation status',
    }, { status: 503 });
  } catch (error) {
    return NextResponse.json({
      error: error instanceof Error ? error.message : 'Unknown error',
    }, { status: 500 });
  }
}
