import * as vscode from 'vscode';
import { getPackageInfo } from './commands/getPackageInfo';
import { getPackageExamples } from './commands/getPackageExamples';
import { getPackagePatterns } from './commands/getPackagePatterns';
import { searchPatterns } from './commands/searchPatterns';
import { analyzeFile } from './commands/analyzeFile';
import { MCP } from './utils/mcp';
import { Logger } from './utils/logger';
import { CopilotChatHandler } from './copilot/chatHandler';

let logger: Logger;
let mcp: MCP;
let statusBarItem: vscode.StatusBarItem;

/**
 * Extension entry point
 */
export async function activate(context: vscode.ExtensionContext) {
  logger = new Logger('Singularity Smart Package Context');

  logger.log('Activating Singularity Smart Package Context extension');

  // Create status bar item
  statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  statusBarItem.command = 'singularitySmartPackageContext.showStatus';
  statusBarItem.text = '$(package) Smart Package Context';
  statusBarItem.tooltip = 'Click to show Singularity Smart Package Context status';
  statusBarItem.show();

  // Initialize MCP client
  try {
    const config = vscode.workspace.getConfiguration('singularitySmartPackageContext');
    const serverUrl = config.get<string>('serverUrl') || 'http://localhost:8888';

    if (!serverUrl) {
      throw new Error('MCP server URL not configured. Set singularitySmartPackageContext.serverUrl in settings.');
    }

    mcp = new MCP(serverUrl, logger);
    await mcp.initialize();

    updateStatusBar('ready');
    logger.log('Extension activated successfully');
  } catch (error) {
    updateStatusBar('error');
    logger.error(`Failed to initialize extension: ${error}`);
    vscode.window.showErrorMessage(
      `Singularity Smart Package Context: Failed to initialize - ${error}`
    );
    return;
  }

  // Register commands
  context.subscriptions.push(
    vscode.commands.registerCommand(
      'singularitySmartPackageContext.getPackageInfo',
      () => getPackageInfo(mcp, logger)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'singularitySmartPackageContext.getPackageExamples',
      () => getPackageExamples(mcp, logger)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'singularitySmartPackageContext.getPackagePatterns',
      () => getPackagePatterns(mcp, logger)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'singularitySmartPackageContext.searchPatterns',
      () => searchPatterns(mcp, logger)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'singularitySmartPackageContext.analyzeFile',
      () => analyzeFile(mcp, logger)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'singularitySmartPackageContext.showStatus',
      () => showStatus()
    )
  );

  // Register Copilot chat handler
  try {
    const copilotChat = vscode.extensions.getExtension('github.copilot-chat');
    if (copilotChat) {
      const chatHandler = new CopilotChatHandler(mcp, logger);
      context.subscriptions.push(
        vscode.chat.registerChatParticipantHandler(
          'singularitySmartPackageContext.chat',
          chatHandler
        )
      );
      logger.log('Copilot chat participant registered');
    }
  } catch (error) {
    logger.warn(`Copilot chat not available: ${error}`);
  }

  // Cleanup on deactivation
  context.subscriptions.push({
    dispose: () => {
      statusBarItem.dispose();
      if (mcp) {
        mcp.dispose();
      }
    }
  });
}

/**
 * Deactivation hook
 */
export function deactivate() {
  if (logger) {
    logger.log('Deactivating extension');
  }
}

/**
 * Update status bar item
 */
function updateStatusBar(status: 'ready' | 'busy' | 'error') {
  const icons = {
    ready: '$(package) Smart Package Context',
    busy: '$(loading~spin) Smart Package Context',
    error: '$(error) Smart Package Context'
  };
  statusBarItem.text = icons[status];
}

/**
 * Show extension status
 */
async function showStatus() {
  if (!mcp) {
    vscode.window.showErrorMessage('Extension not initialized');
    return;
  }

  const outputChannel = vscode.window.createOutputChannel('Singularity Smart Package Context');
  outputChannel.clear();

  outputChannel.appendLine('='.repeat(60));
  outputChannel.appendLine('Singularity Smart Package Context - Status');
  outputChannel.appendLine('='.repeat(60));
  outputChannel.appendLine('');

  outputChannel.appendLine('Status: Ready');
  outputChannel.appendLine('');

  outputChannel.appendLine('Available Commands:');
  outputChannel.appendLine('  • Smart Package Context: Get Package Info');
  outputChannel.appendLine('    → Get complete package metadata with quality score');
  outputChannel.appendLine('');
  outputChannel.appendLine('  • Smart Package Context: Get Package Examples');
  outputChannel.appendLine('    → Get code examples from official documentation');
  outputChannel.appendLine('');
  outputChannel.appendLine('  • Smart Package Context: Get Package Patterns');
  outputChannel.appendLine('    → Get community consensus patterns for a package');
  outputChannel.appendLine('');
  outputChannel.appendLine('  • Smart Package Context: Search Patterns');
  outputChannel.appendLine('    → Search patterns across all packages');
  outputChannel.appendLine('');
  outputChannel.appendLine('  • Smart Package Context: Analyze File');
  outputChannel.appendLine('    → Analyze current file and suggest improvements');
  outputChannel.appendLine('');

  outputChannel.appendLine('Configuration:');
  const config = vscode.workspace.getConfiguration('singularitySmartPackageContext');
  outputChannel.appendLine(`  • Server Path: ${config.get('serverPath') || '(auto)'}`);
  outputChannel.appendLine(`  • Default Ecosystem: ${config.get('defaultEcosystem')}`);
  outputChannel.appendLine(`  • Show Status Bar: ${config.get('showStatusBar')}`);
  outputChannel.appendLine('');

  outputChannel.appendLine('='.repeat(60));
  outputChannel.show();
}
