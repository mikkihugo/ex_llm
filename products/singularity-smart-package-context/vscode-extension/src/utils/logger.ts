import * as vscode from 'vscode';

/**
 * Logger for extension
 */
export class Logger {
  private outputChannel: vscode.OutputChannel;

  constructor(name: string) {
    this.outputChannel = vscode.window.createOutputChannel(name);
  }

  /**
   * Log a message
   */
  log(message: string) {
    const timestamp = new Date().toLocaleTimeString();
    this.outputChannel.appendLine(`[${timestamp}] ${message}`);
  }

  /**
   * Log an error
   */
  error(message: string) {
    const timestamp = new Date().toLocaleTimeString();
    this.outputChannel.appendLine(`[${timestamp}] ERROR: ${message}`);
  }

  /**
   * Log a warning
   */
  warn(message: string) {
    const timestamp = new Date().toLocaleTimeString();
    this.outputChannel.appendLine(`[${timestamp}] WARN: ${message}`);
  }

  /**
   * Show the output channel
   */
  show() {
    this.outputChannel.show();
  }

  /**
   * Clear the output channel
   */
  clear() {
    this.outputChannel.clear();
  }

  /**
   * Dispose the output channel
   */
  dispose() {
    this.outputChannel.dispose();
  }
}
