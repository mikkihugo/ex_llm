/**
 * Simple File + Console Logger
 * 
 * Logs to both console and file for better debugging and monitoring.
 */

import { writeFileSync, appendFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';

const LOG_DIR = join(process.cwd(), '..', 'logs');
const LOG_FILE = join(LOG_DIR, 'ai-server.log');

// Ensure log directory exists
if (!existsSync(LOG_DIR)) {
  mkdirSync(LOG_DIR, { recursive: true });
}

// Initialize log file with timestamp
const startupMessage = `\n${'='.repeat(80)}\nAI Server Started: ${new Date().toISOString()}\n${'='.repeat(80)}\n`;
if (!existsSync(LOG_FILE)) {
  writeFileSync(LOG_FILE, startupMessage);
} else {
  appendFileSync(LOG_FILE, startupMessage);
}

function formatMessage(level: string, message: string, ...args: any[]): string {
  const timestamp = new Date().toISOString();
  const formattedArgs = args.length > 0 ? ' ' + args.map(arg => 
    typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
  ).join(' ') : '';
  return `[${timestamp}] [${level}] ${message}${formattedArgs}`;
}

function writeToFile(message: string): void {
  try {
    appendFileSync(LOG_FILE, message + '\n');
  } catch (error) {
    // Fallback to console only if file write fails
    console.error('Failed to write to log file:', error);
  }
}

export const logger = {
  info(message: string, ...args: any[]): void {
    const formatted = formatMessage('INFO', message, ...args);
    console.log(message, ...args); // Keep original console formatting
    writeToFile(formatted);
  },

  warn(message: string, ...args: any[]): void {
    const formatted = formatMessage('WARN', message, ...args);
    console.warn(message, ...args);
    writeToFile(formatted);
  },

  error(message: string, ...args: any[]): void {
    const formatted = formatMessage('ERROR', message, ...args);
    console.error(message, ...args);
    writeToFile(formatted);
  },

  debug(message: string, ...args: any[]): void {
    if (process.env.DEBUG === 'true') {
      const formatted = formatMessage('DEBUG', message, ...args);
      console.log(message, ...args);
      writeToFile(formatted);
    }
  },

  // Metrics logging
  metric(metric: string, value: number | string, tags?: Record<string, string>): void {
    const tagsStr = tags ? ' ' + Object.entries(tags).map(([k, v]) => `${k}=${v}`).join(' ') : '';
    const formatted = formatMessage('METRIC', `${metric}=${value}${tagsStr}`);
    writeToFile(formatted);
  }
};

// Export a shutdown function to close logs gracefully
export function closeLogger(): void {
  const shutdownMessage = `\nAI Server Shutdown: ${new Date().toISOString()}\n${'='.repeat(80)}\n`;
  writeToFile(shutdownMessage);
}

// Handle process termination
process.on('SIGINT', () => {
  closeLogger();
  process.exit(0);
});

process.on('SIGTERM', () => {
  closeLogger();
  process.exit(0);
});
