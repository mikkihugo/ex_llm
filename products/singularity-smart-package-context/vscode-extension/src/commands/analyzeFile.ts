import * as vscode from 'vscode';
import { MCP } from '../utils/mcp';
import { Logger } from '../utils/logger';

/**
 * Analyze file command
 */
export async function analyzeFile(mcp: MCP, logger: Logger) {
  const editor = vscode.window.activeTextEditor;

  if (!editor) {
    vscode.window.showErrorMessage('No active editor');
    return;
  }

  const document = editor.document;
  const content = document.getText();
  const language = document.languageId;

  try {
    vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Analyzing ${language} file...`,
        cancellable: false
      },
      async () => {
        const result = await mcp.call('analyze_file', {
          content,
          file_type: language
        });

        if (!result.success) {
          vscode.window.showErrorMessage(
            `Failed to analyze file: ${result.error}`
          );
          return;
        }

        displaySuggestions(language, result.result);
      }
    );
  } catch (error) {
    logger.error(`Error analyzing file: ${error}`);
    vscode.window.showErrorMessage(`Error: ${error}`);
  }
}

/**
 * Display suggestions in output channel
 */
function displaySuggestions(language: string, suggestions: any[]) {
  const outputChannel = vscode.window.createOutputChannel(
    'Singularity Smart Package Context'
  );
  outputChannel.clear();

  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine(`File Analysis: ${language}`);
  outputChannel.appendLine(`Found ${suggestions.length} suggestions`);
  outputChannel.appendLine('='.repeat(70));
  outputChannel.appendLine('');

  if (suggestions.length === 0) {
    outputChannel.appendLine('No suggestions found. Code looks good!');
    outputChannel.show();
    return;
  }

  // Sort by severity
  const severityOrder: Record<string, number> = {
    error: 0,
    warning: 1,
    info: 2
  };

  const sorted = suggestions.sort((a, b) => {
    const aSev = severityOrder[a.severity] ?? 3;
    const bSev = severityOrder[b.severity] ?? 3;
    return aSev - bSev;
  });

  sorted.forEach((suggestion) => {
    const icon = {
      error: '❌',
      warning: '⚠️',
      info: 'ℹ️'
    }[suggestion.severity] || '•';

    outputChannel.appendLine(`${icon} ${suggestion.title}`);
    outputChannel.appendLine(`  Severity: ${suggestion.severity}`);

    if (suggestion.description) {
      outputChannel.appendLine(`  ${suggestion.description}`);
    }

    if (suggestion.pattern) {
      outputChannel.appendLine(`  Suggested Pattern: ${suggestion.pattern.name}`);
      if (suggestion.pattern.description) {
        outputChannel.appendLine(`  ${suggestion.pattern.description}`);
      }
    }

    if (suggestion.example) {
      outputChannel.appendLine('  Example:');
      suggestion.example.split('\n').forEach((line: string) => {
        outputChannel.appendLine(`    ${line}`);
      });
    }

    outputChannel.appendLine('');
  });

  outputChannel.appendLine('='.repeat(70));
  outputChannel.show();
}
