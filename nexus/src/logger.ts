/**
 * @file Simple File + Console Logger
 * @description A simple logger that writes to both the console and a log file.
 * This is useful for debugging and monitoring the AI server in production and
 * development environments. It supports different log levels (INFO, WARN, ERROR, DEBUG)
 * and structured metrics logging.
 */

import { writeFileSync, appendFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

const LOG_DIR = join(process.cwd(), '..', 'logs');
const LOG_FILE = join(LOG_DIR, 'llm-server.log');

// Ensure log directory exists
if (!existsSync(LOG_DIR)) {
  mkdirSync(LOG_DIR, { recursive: true });
}

// Initialize log file with a startup message
const startupMessage = `\n${'='.repeat(80)}\nAI Server Started: ${new Date().toISOString()}\n${'='.repeat(80)}\n`;
if (!existsSync(LOG_FILE)) {
  writeFileSync(LOG_FILE, startupMessage);
} else {
  appendFileSync(LOG_FILE, startupMessage);
}

/**
 * Formats a log message with a timestamp and level.
 * @private
 * @param {string} level The log level (e.g., 'INFO', 'ERROR').
 * @param {string} message The main log message.
 * @param {...any[]} args Additional arguments to log.
 * @returns {string} The formatted log message.
 */
function formatMessage(level: string, message: string, ...args: any[]): string {
  const timestamp = new Date().toISOString();
  const formattedArgs = args.length > 0 ? ' ' + args.map(arg => 
    typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
  ).join(' ') : '';
  return `[${timestamp}] [${level}] ${message}${formattedArgs}`;
}

/**
 * Writes a formatted message to the log file.
 * @private
 * @param {string} message The message to write.
 */
function writeToFile(message: string): void {
  try {
    appendFileSync(LOG_FILE, message + '\n');
  } catch (error) {
    // Fallback to console only if file write fails
    console.error('Failed to write to log file:', error);
  }
}

/**
 * @const {object} logger
 * @description A simple logger object with methods for different log levels.
 */
export const logger = {
  /**
   * Logs an informational message.
   * @param {string} message The message to log.
   * @param {...any[]} args Additional arguments to log.
   */
  info(message: string, ...args: any[]): void {
    const formatted = formatMessage('INFO', message, ...args);
    console.log(message, ...args);
    writeToFile(formatted);
  },

  /**
   * Logs a warning message.
   * @param {string} message The message to log.
   * @param {...any[]} args Additional arguments to log.
   */
  warn(message: string, ...args: any[]): void {
    const formatted = formatMessage('WARN', message, ...args);
    console.warn(message, ...args);
    writeToFile(formatted);
  },

  /**
   * Logs an error message.
   * @param {string} message The message to log.
   * @param {...any[]} args Additional arguments to log.
   */
  error(message: string, ...args: any[]): void {
    const formatted = formatMessage('ERROR', message, ...args);
    console.error(message, ...args);
    writeToFile(formatted);
  },

  /**
   * Logs a debug message. Only logs if the DEBUG environment variable is set to 'true'.
   * @param {string} message The message to log.
   * @param {...any[]} args Additional arguments to log.
   */
  debug(message: string, ...args: any[]): void {
    if (process.env.DEBUG === 'true') {
      const formatted = formatMessage('DEBUG', message, ...args);
      console.log(message, ...args);
      writeToFile(formatted);
    }
  },

  /**
   * Logs a structured metric.
   * @param {string} metric The name of the metric.
   * @param {number | string} value The value of the metric.
   * @param {Record<string, string>} [tags] Optional tags for the metric.
   */
  metric(metric: string, value: number | string, tags?: Record<string, string>): void {
    const tagsStr = tags ? ' ' + Object.entries(tags).map(([k, v]) => `${k}=${v}`).join(' ') : '';
    const formatted = formatMessage('METRIC', `${metric}=${value}${tagsStr}`);
    writeToFile(formatted);
  }
};

/**
 * Writes a shutdown message to the log file.
 * This should be called before the process exits to ensure logs are complete.
 */
export function closeLogger(): void {
  const shutdownMessage = `\nAI Server Shutdown: ${new Date().toISOString()}\n${'='.repeat(80)}\n`;
  writeToFile(shutdownMessage);
}

// Handle process termination to ensure logs are closed gracefully
process.on('SIGINT', () => {
  closeLogger();
  process.exit(0);
});

process.on('SIGTERM', () => {
  closeLogger();
  process.exit(0);
});
