import * as vscode from 'vscode';
import { MCP } from '../utils/mcp';
import { Logger } from '../utils/logger';

/**
 * Get package patterns command
 */
export async function getPackagePatterns(mcp: MCP, logger: Logger) {
  const packageName = await vscode.window.showInputBox({
    prompt: 'Enter package name',
    placeHolder: 'e.g., react'
  });

  if (!packageName) {
    return;
  }

  try {
    vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Fetching patterns for ${packageName}...`,
        cancellable: false
      },
      async () => {
        const result = await mcp.call('get_package_patterns', {
          name: packageName
        });

        if (!result.success) {
          vscode.window.showErrorMessage(
            `Failed to get patterns: ${result.error}`
          );
          return;
        }

        displayPatterns(packageName, result.result);
      }
    );
  } catch (error) {
    logger.error(`Error getting package patterns: ${error}`);
    vscode.window.showErrorMessage(`Error: ${error}`);
  }
}

/**
 * Display patterns in output channel
 */
function displayPatterns(packageName: string, patterns: any[]) {
  const outputChannel = vscode.window.createOutputChannel(
    'Singularity Smart Package Context'
  );
  outputChannel.clear();

  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine(`Patterns for ${packageName}`);
  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine('');

  // Sort by confidence descending
  const sorted = patterns.sort(
    (a, b) => (b.confidence || 0) - (a.confidence || 0)
  );

  sorted.forEach((pattern) => {
    const confidence = ((pattern.confidence || 0) * 100).toFixed(0);
    const recommendedLabel = pattern.recommended ? ' [RECOMMENDED]' : '';

    outputChannel.appendLine(`• ${pattern.name}${recommendedLabel}`);
    outputChannel.appendLine(`  Type: ${pattern.pattern_type}`);
    outputChannel.appendLine(`  Confidence: ${confidence}%`);
    outputChannel.appendLine(`  Observations: ${pattern.observation_count}`);

    if (pattern.description) {
      outputChannel.appendLine(`  Description: ${pattern.description}`);
    }

    outputChannel.appendLine('');
  });

  outputChannel.appendLine('='.repeat(70));
  outputChannel.show();
}
