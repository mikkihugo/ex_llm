import * as vscode from 'vscode';
import { MCP } from '../utils/mcp';
import { Logger } from '../utils/logger';

/**
 * Get package info command
 */
export async function getPackageInfo(mcp: MCP, logger: Logger) {
  const packageName = await vscode.window.showInputBox({
    prompt: 'Enter package name',
    placeHolder: 'e.g., react, tokio, phoenix'
  });

  if (!packageName) {
    return;
  }

  const config = vscode.workspace.getConfiguration('singularitySmartPackageContext');
  const defaultEcosystem = config.get<string>('defaultEcosystem') || 'npm';

  const ecosystem = await vscode.window.showQuickPick(
    ['npm', 'cargo', 'hex', 'pypi', 'go', 'maven', 'nuget'],
    {
      placeHolder: 'Select ecosystem',
      title: 'Package Ecosystem'
    }
  ) || defaultEcosystem;

  try {
    vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Fetching package info for ${packageName}...`,
        cancellable: false
      },
      async () => {
        const result = await mcp.call('get_package_info', {
          name: packageName,
          ecosystem
        });

        if (!result.success) {
          vscode.window.showErrorMessage(
            `Failed to get package info: ${result.error}`
          );
          return;
        }

        displayPackageInfo(result.result);
      }
    );
  } catch (error) {
    logger.error(`Error getting package info: ${error}`);
    vscode.window.showErrorMessage(`Error: ${error}`);
  }
}

/**
 * Display package info in output channel
 */
function displayPackageInfo(pkg: any) {
  const outputChannel = vscode.window.createOutputChannel(
    'Singularity Smart Package Context'
  );
  outputChannel.clear();

  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine(`Package: ${pkg.name}`);
  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine('');

  outputChannel.appendLine(`Version: ${pkg.version}`);
  outputChannel.appendLine(`Ecosystem: ${pkg.ecosystem}`);
  outputChannel.appendLine('');

  if (pkg.description) {
    outputChannel.appendLine(`Description:`);
    outputChannel.appendLine(`  ${pkg.description}`);
    outputChannel.appendLine('');
  }

  outputChannel.appendLine(`Quality Score: ${pkg.quality_score.toFixed(1)}/100`);
  outputChannel.appendLine('');

  if (pkg.downloads) {
    outputChannel.appendLine('Downloads:');
    outputChannel.appendLine(`  Per Week: ${pkg.downloads.per_week.toLocaleString()}`);
    outputChannel.appendLine(`  Per Month: ${pkg.downloads.per_month.toLocaleString()}`);
    outputChannel.appendLine(`  Per Year: ${pkg.downloads.per_year.toLocaleString()}`);
    outputChannel.appendLine('');
  }

  if (pkg.repository) {
    outputChannel.appendLine(`Repository: ${pkg.repository}`);
  }

  if (pkg.documentation) {
    outputChannel.appendLine(`Documentation: ${pkg.documentation}`);
  }

  if (pkg.homepage) {
    outputChannel.appendLine(`Homepage: ${pkg.homepage}`);
  }

  if (pkg.license) {
    outputChannel.appendLine(`License: ${pkg.license}`);
  }

  if (pkg.dependents) {
    outputChannel.appendLine(`Dependents: ${pkg.dependents}`);
  }

  outputChannel.appendLine('');
  outputChannel.appendLine('='.repeat(70));

  outputChannel.show();
}
