import * as vscode from 'vscode';
import { MCP } from '../utils/mcp';
import { Logger } from '../utils/logger';

/**
 * Get package examples command
 */
export async function getPackageExamples(mcp: MCP, logger: Logger) {
  const packageName = await vscode.window.showInputBox({
    prompt: 'Enter package name',
    placeHolder: 'e.g., react'
  });

  if (!packageName) {
    return;
  }

  const config = vscode.workspace.getConfiguration('singularitySmartPackageContext');
  const defaultEcosystem = config.get<string>('defaultEcosystem') || 'npm';

  const ecosystem = await vscode.window.showQuickPick(
    ['npm', 'cargo', 'hex', 'pypi', 'go', 'maven', 'nuget'],
    { placeHolder: 'Select ecosystem' }
  ) || defaultEcosystem;

  try {
    vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Fetching examples for ${packageName}...`,
        cancellable: false
      },
      async () => {
        const result = await mcp.call('get_package_examples', {
          name: packageName,
          ecosystem,
          limit: 5
        });

        if (!result.success) {
          vscode.window.showErrorMessage(
            `Failed to get examples: ${result.error}`
          );
          return;
        }

        displayExamples(packageName, result.result);
      }
    );
  } catch (error) {
    logger.error(`Error getting package examples: ${error}`);
    vscode.window.showErrorMessage(`Error: ${error}`);
  }
}

/**
 * Display examples in output channel
 */
function displayExamples(packageName: string, examples: any[]) {
  const outputChannel = vscode.window.createOutputChannel(
    'Singularity Smart Package Context'
  );
  outputChannel.clear();

  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine(`Examples for ${packageName}`);
  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine('');

  examples.forEach((example, index) => {
    outputChannel.appendLine(`${index + 1}. ${example.title}`);

    if (example.description) {
      outputChannel.appendLine(`   ${example.description}`);
    }

    outputChannel.appendLine('');
    outputChannel.appendLine('   Code:');
    example.code.split('\n').forEach((line: string) => {
      outputChannel.appendLine(`   ${line}`);
    });

    if (example.source_url) {
      outputChannel.appendLine(`   Source: ${example.source_url}`);
    }

    outputChannel.appendLine('');
  });

  outputChannel.appendLine('='.repeat(70));
  outputChannel.show();
}
