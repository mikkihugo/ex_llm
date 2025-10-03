// @ts-nocheck
import { createLanguageModel } from "ai";
import { spawn } from "node:child_process";

function stringifyMessageContent(content: any): string {
  if (content == null) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) return content.map(stringifyMessageContent).join("\n");
  if (typeof content === "object") {
    if ("text" in content) return stringifyMessageContent(content.text);
    if ("content" in content) return stringifyMessageContent((content as any).content);
    return JSON.stringify(content);
  }
  return String(content);
}

function buildPrompt(opts: { prompt?: string; messages?: any[] }): string {
  const parts: string[] = [];
  if (opts.prompt) {
    parts.push(opts.prompt);
  }
  for (const message of opts.messages ?? []) {
    const role = message.role ?? "user";
    parts.push(`${role.toUpperCase()}: ${stringifyMessageContent(message.content)}`);
  }
  return parts.join("\n\n").trim();
}

async function runCommand(command: string, args: string[], stdin?: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", reject);

    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || stdout || `Command ${command} exited with ${code}`));
      } else {
        resolve(stdout);
      }
    });

    if (stdin) {
      child.stdin.write(stdin);
    }
    child.stdin.end();
  });
}

function extractClaudeText(raw: string): string {
  const trimmed = raw.trim();
  const candidates = trimmed.split(/\n+/g).reverse();
  for (const entry of candidates) {
    try {
      const parsed = JSON.parse(entry);
      if (parsed?.is_error) {
        throw new Error(parsed?.result ?? "Claude CLI reported an error");
      }
      const text = stringifyMessageContent(parsed?.response ?? parsed?.result ?? parsed?.message ?? parsed?.completion ?? parsed);
      if (text) return text;
    } catch (error) {
      continue;
    }
  }
  return trimmed;
}

function extractCodexText(raw: string): string {
  let lastMessage = "";
  for (const line of raw.split(/\n+/g)) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("{")) continue;
    try {
      const parsed = JSON.parse(trimmed);
      const message = parsed?.msg;
      if (message?.type === "agent_message") {
        const value = message.message ?? message.content ?? message.text;
        lastMessage = stringifyMessageContent(value);
      }
    } catch (error) {
      continue;
    }
  }
  return lastMessage || raw.trim();
}

export const claudeCliLanguageModel = createLanguageModel({
  doGenerate: async (options) => {
    const prompt = buildPrompt(options);
    const model = options.model ?? process.env.CLAUDE_DEFAULT_MODEL ?? "sonnet";
    const args = ["--print", "--output-format", "json", "--model", model, prompt];
    const output = await runCommand("claude", args);
    const text = extractClaudeText(output);
    return {
      type: "text-generation",
      text,
      usage: {
        inputTokens: prompt.length,
        outputTokens: text.length,
      },
    };
  },
});

export const codexCliLanguageModel = createLanguageModel({
  doGenerate: async (options) => {
    const prompt = buildPrompt(options);
    const model = options.model ?? "gpt-5-codex";
    const sandbox = process.env.CODEX_SANDBOX ?? "read-only";
    const args = [
      "exec",
      "--experimental-json",
      "--skip-git-repo-check",
      "--sandbox",
      sandbox,
      "--model",
      model,
      prompt,
    ];
    const output = await runCommand("codex", args);
    const text = extractCodexText(output);
    return {
      type: "text-generation",
      text,
      usage: {
        inputTokens: prompt.length,
        outputTokens: text.length,
      },
    };
  },
});
