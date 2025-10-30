import * as vscode from 'vscode';
import { MCP } from '../utils/mcp';
import { Logger } from '../utils/logger';

/**
 * Search patterns command
 */
export async function searchPatterns(mcp: MCP, logger: Logger) {
  const query = await vscode.window.showInputBox({
    prompt: 'Enter search query',
    placeHolder: 'e.g., async error handling'
  });

  if (!query) {
    return;
  }

  try {
    vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Searching patterns: "${query}"...`,
        cancellable: false
      },
      async () => {
        const result = await mcp.call('search_patterns', {
          query,
          limit: 10
        });

        if (!result.success) {
          vscode.window.showErrorMessage(
            `Failed to search patterns: ${result.error}`
          );
          return;
        }

        displaySearchResults(query, result.result);
      }
    );
  } catch (error) {
    logger.error(`Error searching patterns: ${error}`);
    vscode.window.showErrorMessage(`Error: ${error}`);
  }
}

/**
 * Display search results in output channel
 */
function displaySearchResults(query: string, results: any[]) {
  const outputChannel = vscode.window.createOutputChannel(
    'Singularity Smart Package Context'
  );
  outputChannel.clear();

  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine(`Pattern Search: "${query}"`);
  outputChannel.appendLine(`Found ${results.length} results`);
  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine('');

  if (results.length === 0) {
    outputChannel.appendLine('No patterns found matching your query.');
    outputChannel.show();
    return;
  }

  // Sort by relevance
  const sorted = results.sort(
    (a, b) => (b.relevance || 0) - (a.relevance || 0)
  );

  sorted.forEach((match, index) => {
    const relevance = ((match.relevance || 0) * 100).toFixed(0);
    const confidence = ((match.pattern?.confidence || 0) * 100).toFixed(0);

    outputChannel.appendLine(`${index + 1}. ${match.pattern.name}`);
    outputChannel.appendLine(`   Package: ${match.package} (${match.ecosystem})`);
    outputChannel.appendLine(`   Type: ${match.pattern.pattern_type}`);
    outputChannel.appendLine(`   Relevance: ${relevance}%`);
    outputChannel.appendLine(`   Confidence: ${confidence}%`);

    if (match.pattern.description) {
      outputChannel.appendLine(`   Description: ${match.pattern.description}`);
    }

    outputChannel.appendLine('');
  });

  outputChannel.appendLine('='.repeat(70));
  outputChannel.show();
}
