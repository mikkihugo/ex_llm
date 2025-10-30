import * as vscode from 'vscode';
import { MCP } from '../utils/mcp';
import { Logger } from '../utils/logger';

/**
 * Copilot Chat handler for Singularity Smart Package Context
 */
export class CopilotChatHandler implements vscode.ChatParticipantHandler {
  constructor(private mcp: MCP, private logger: Logger) {}

  async provideChatParticipantResponse(
    request: vscode.ChatRequest,
    context: vscode.ChatContext,
    stream: vscode.ChatResponseStream,
    _token: vscode.CancellationToken
  ): Promise<vscode.ChatResult> {
    try {
      const command = request.command || '';
      const prompt = request.prompt || '';

      this.logger.log(`Copilot chat: @smartpackage ${command} "${prompt}"`);

      switch (command) {
        case 'info':
          return await this.handleInfo(prompt, stream);

        case 'examples':
          return await this.handleExamples(prompt, stream);

        case 'patterns':
          return await this.handlePatterns(prompt, stream);

        case 'search':
          return await this.handleSearch(prompt, stream);

        default:
          // No command specified - show help
          return await this.handleHelp(prompt, stream);
      }
    } catch (error) {
      this.logger.error(`Error in copilot chat: ${error}`);
      return { metadata: { command: 'error' } };
    }
  }

  /**
   * Handle @smartpackage info <package>
   */
  private async handleInfo(prompt: string, stream: vscode.ChatResponseStream) {
    stream.progress(`Fetching package info for "${prompt}"...`);

    try {
      const result = await this.mcp.call('get_package_info', {
        name: prompt,
        ecosystem: 'npm'
      });

      if (!result.success) {
        stream.markdown(`❌ Error: ${result.error}`);
        return { metadata: { command: 'info', error: result.error } };
      }

      const pkg = result.result;
      const markdown = this.formatPackageInfo(pkg);
      stream.markdown(markdown);

      return {
        metadata: {
          command: 'info',
          package: pkg.name,
          quality: pkg.quality_score
        }
      };
    } catch (error) {
      stream.markdown(`❌ Failed to get package info: ${error}`);
      return { metadata: { command: 'info', error: String(error) } };
    }
  }

  /**
   * Handle @smartpackage examples <package>
   */
  private async handleExamples(prompt: string, stream: vscode.ChatResponseStream) {
    stream.progress(`Fetching examples for "${prompt}"...`);

    try {
      const result = await this.mcp.call('get_package_examples', {
        name: prompt,
        ecosystem: 'npm',
        limit: 3
      });

      if (!result.success) {
        stream.markdown(`❌ Error: ${result.error}`);
        return { metadata: { command: 'examples', error: result.error } };
      }

      const examples = result.result;
      let markdown = `## Examples for ${prompt}\n\n`;

      examples.forEach((example: any, index: number) => {
        markdown += `### ${index + 1}. ${example.title}\n`;
        if (example.description) {
          markdown += `${example.description}\n\n`;
        }
        markdown += '```' + example.language + '\n';
        markdown += example.code + '\n';
        markdown += '```\n\n';
        if (example.source_url) {
          markdown += `[View source](${example.source_url})\n\n`;
        }
      });

      stream.markdown(markdown);

      return {
        metadata: {
          command: 'examples',
          package: prompt,
          count: examples.length
        }
      };
    } catch (error) {
      stream.markdown(`❌ Failed to get examples: ${error}`);
      return { metadata: { command: 'examples', error: String(error) } };
    }
  }

  /**
   * Handle @smartpackage patterns <package>
   */
  private async handlePatterns(prompt: string, stream: vscode.ChatResponseStream) {
    stream.progress(`Fetching patterns for "${prompt}"...`);

    try {
      const result = await this.mcp.call('get_package_patterns', {
        name: prompt
      });

      if (!result.success) {
        stream.markdown(`❌ Error: ${result.error}`);
        return { metadata: { command: 'patterns', error: result.error } };
      }

      const patterns = result.result;
      let markdown = `## Best Practices for ${prompt}\n\n`;

      // Sort by confidence
      const sorted = patterns.sort((a: any, b: any) => (b.confidence || 0) - (a.confidence || 0));

      sorted.forEach((pattern: any) => {
        const confidence = ((pattern.confidence || 0) * 100).toFixed(0);
        const recommended = pattern.recommended ? ' ✅ RECOMMENDED' : '';

        markdown += `### ${pattern.name}${recommended}\n`;
        markdown += `**Confidence:** ${confidence}% | **Type:** ${pattern.pattern_type}\n\n`;

        if (pattern.description) {
          markdown += `${pattern.description}\n\n`;
        }

        markdown += `*Observed ${pattern.observation_count} times in community code*\n\n`;
      });

      stream.markdown(markdown);

      return {
        metadata: {
          command: 'patterns',
          package: prompt,
          count: patterns.length
        }
      };
    } catch (error) {
      stream.markdown(`❌ Failed to get patterns: ${error}`);
      return { metadata: { command: 'patterns', error: String(error) } };
    }
  }

  /**
   * Handle @smartpackage search <query>
   */
  private async handleSearch(prompt: string, stream: vscode.ChatResponseStream) {
    stream.progress(`Searching for patterns: "${prompt}"...`);

    try {
      const result = await this.mcp.call('search_patterns', {
        query: prompt,
        limit: 5
      });

      if (!result.success) {
        stream.markdown(`❌ Error: ${result.error}`);
        return { metadata: { command: 'search', error: result.error } };
      }

      const results = result.result;
      let markdown = `## Pattern Search Results\n\n`;
      markdown += `**Query:** "${prompt}"\n\n`;

      if (results.length === 0) {
        markdown += 'No patterns found matching your query.';
      } else {
        // Sort by relevance
        const sorted = results.sort((a: any, b: any) => (b.relevance || 0) - (a.relevance || 0));

        sorted.forEach((match: any, index: number) => {
          const relevance = ((match.relevance || 0) * 100).toFixed(0);
          const confidence = ((match.pattern?.confidence || 0) * 100).toFixed(0);

          markdown += `${index + 1}. **${match.pattern.name}** in **${match.package}**\n`;
          markdown += `   - **Relevance:** ${relevance}% | **Confidence:** ${confidence}%\n`;
          markdown += `   - **Type:** ${match.pattern.pattern_type}\n`;

          if (match.pattern.description) {
            markdown += `   - ${match.pattern.description}\n`;
          }

          markdown += '\n';
        });
      }

      stream.markdown(markdown);

      return {
        metadata: {
          command: 'search',
          query: prompt,
          count: results.length
        }
      };
    } catch (error) {
      stream.markdown(`❌ Failed to search patterns: ${error}`);
      return { metadata: { command: 'search', error: String(error) } };
    }
  }

  /**
   * Handle help - no command specified
   */
  private async handleHelp(prompt: string, stream: vscode.ChatResponseStream) {
    let markdown = `## Singularity Smart Package Context\n\n`;
    markdown += `Know before you code - Package intelligence powered by community consensus.\n\n`;
    markdown += `### Available Commands\n\n`;
    markdown += `- **@smartpackage info <package>** - Get package metadata and quality score\n`;
    markdown += `- **@smartpackage examples <package>** - Get code examples from documentation\n`;
    markdown += `- **@smartpackage patterns <package>** - Get community consensus best practices\n`;
    markdown += `- **@smartpackage search <query>** - Search patterns with natural language\n\n`;

    markdown += `### Examples\n\n`;
    markdown += `\`\`\`\n`;
    markdown += `@smartpackage info react\n`;
    markdown += `@smartpackage examples next.js\n`;
    markdown += `@smartpackage patterns tokio\n`;
    markdown += `@smartpackage search async error handling\n`;
    markdown += `\`\`\`\n`;

    stream.markdown(markdown);

    return { metadata: { command: 'help' } };
  }

  /**
   * Format package info as markdown
   */
  private formatPackageInfo(pkg: any): string {
    let markdown = `# ${pkg.name}\n\n`;

    markdown += `**Version:** \`${pkg.version}\` | **Quality Score:** ${pkg.quality_score.toFixed(1)}/100\n\n`;

    if (pkg.description) {
      markdown += `${pkg.description}\n\n`;
    }

    if (pkg.downloads) {
      markdown += `### Downloads\n`;
      markdown += `- **Per Week:** ${(pkg.downloads.per_week / 1000000).toFixed(1)}M\n`;
      markdown += `- **Per Month:** ${(pkg.downloads.per_month / 1000000).toFixed(1)}M\n`;
      markdown += `- **Per Year:** ${(pkg.downloads.per_year / 1000000).toFixed(1)}M\n\n`;
    }

    if (pkg.repository || pkg.documentation || pkg.homepage) {
      markdown += `### Links\n`;
      if (pkg.repository) {
        markdown += `- [Repository](${pkg.repository})\n`;
      }
      if (pkg.documentation) {
        markdown += `- [Documentation](${pkg.documentation})\n`;
      }
      if (pkg.homepage) {
        markdown += `- [Homepage](${pkg.homepage})\n`;
      }
      markdown += '\n';
    }

    if (pkg.license) {
      markdown += `**License:** ${pkg.license}\n\n`;
    }

    if (pkg.dependents) {
      markdown += `**Dependents:** ${pkg.dependents.toLocaleString()}\n`;
    }

    return markdown;
  }
}
