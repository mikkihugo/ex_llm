import { json, type ActionFunctionArgs, type LoaderFunctionArgs } from "@remix-run/node";
import { useLoaderData, useFetcher, Form } from "@remix-run/react";
import { GoogleAuth } from "google-auth-library";
import { exec } from "child_process";
import { promisify } from "util";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import { useState } from "react";

const execAsync = promisify(exec);

interface GoogleProject {
  projectId: string;
  projectNumber: string;
  displayName: string;
  lifecycleState: string;
}

interface ProviderConfig {
  google: {
    authenticated: boolean;
    email?: string;
    currentProject?: string;
    projects: GoogleProject[];
  };
  openrouter: {
    configured: boolean;
    apiKeySet: boolean;
  };
  github: {
    authenticated: boolean;
    username?: string;
  };
  codex: {
    configured: boolean;
    authMethod?: 'oauth' | 'api_key';
  };
}

interface LoaderData {
  providers: ProviderConfig;
}

export async function loader({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const action = url.searchParams.get("action");
  const provider = url.searchParams.get("provider");

  // Initialize provider configs
  const providers: ProviderConfig = {
    google: { authenticated: false, projects: [] },
    openrouter: { configured: false, apiKeySet: false },
    github: { authenticated: false },
    codex: { configured: false }
  };

  // Check Google authentication
  try {
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/cloud-platform']
    });

    const client = await auth.getClient();
    const credentials = await client.getAccessToken();

    if (credentials.token) {
      const tokenInfo = await client.getTokenInfo(credentials.token);
      const projectId = await auth.getProjectId().catch(() => process.env.GEMINI_CODE_PROJECT);

      providers.google = {
        authenticated: true,
        email: tokenInfo.email,
        currentProject: projectId,
        projects: []
      };

      // Fetch projects if requested
      if (action === "fetch-projects" && provider === "google") {
        const response = await fetch(
          'https://cloudresourcemanager.googleapis.com/v1/projects',
          {
            headers: {
              'Authorization': `Bearer ${credentials.token}`,
              'Content-Type': 'application/json'
            }
          }
        );

        if (response.ok) {
          const data = await response.json();
          providers.google.projects = (data.projects || [])
            .filter((p: any) => p.lifecycleState === 'ACTIVE')
            .map((p: any) => ({
              projectId: p.projectId,
              projectNumber: p.projectNumber,
              displayName: p.displayName || p.projectId,
              lifecycleState: p.lifecycleState
            }));
        }
      }
    }
  } catch (error) {
    // Google not authenticated
  }

  // Check OpenRouter API key
  if (process.env.OPENROUTER_API_KEY) {
    providers.openrouter = {
      configured: true,
      apiKeySet: true
    };
  }

  // Check GitHub authentication
  if (process.env.GITHUB_TOKEN) {
    try {
      const response = await fetch('https://api.github.com/user', {
        headers: {
          'Authorization': `Bearer ${process.env.GITHUB_TOKEN}`,
          'Accept': 'application/vnd.github+json'
        }
      });

      if (response.ok) {
        const data = await response.json();
        providers.github = {
          authenticated: true,
          username: data.login
        };
      }
    } catch (error) {
      // GitHub not authenticated
    }
  }

  // Check Codex/OpenAI
  if (process.env.OPENAI_API_KEY) {
    providers.codex = {
      configured: true,
      authMethod: 'api_key'
    };
  }

  return json<LoaderData>({ providers });
}

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const intent = formData.get("intent") as string;
  const provider = formData.get("provider") as string;

  const envrcPath = join(process.cwd(), '../.envrc.local');

  // Google Gemini OAuth login
  if (intent === "login" && provider === "google") {
    try {
      await execAsync('bunx @google/gemini-cli auth', {
        timeout: 120000
      });
      return json({ success: true });
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'Login failed' },
        { status: 500 }
      );
    }
  }

  // Google project selection
  if (intent === "set-project" && provider === "google") {
    const projectId = formData.get("projectId") as string;

    if (!projectId) {
      return json({ error: 'Invalid project ID' }, { status: 400 });
    }

    try {
      const envContent = `\n# Google Cloud Project (set via Nexus settings)\nexport GEMINI_CODE_PROJECT="${projectId}"\nexport GOOGLE_CLOUD_PROJECT="${projectId}"\nexport CLOUDSDK_CORE_PROJECT="${projectId}"\n`;

      await writeFile(envrcPath, envContent, { flag: 'a' });

      process.env.GEMINI_CODE_PROJECT = projectId;
      process.env.GOOGLE_CLOUD_PROJECT = projectId;
      process.env.CLOUDSDK_CORE_PROJECT = projectId;

      return json({ success: true, projectId });
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'Failed to set project' },
        { status: 500 }
      );
    }
  }

  // OpenRouter API key
  if (intent === "set-api-key" && provider === "openrouter") {
    const apiKey = formData.get("apiKey") as string;

    if (!apiKey || !apiKey.startsWith('sk-or-')) {
      return json({ error: 'Invalid OpenRouter API key (must start with sk-or-)' }, { status: 400 });
    }

    try {
      const envContent = `\n# OpenRouter API Key (set via Nexus settings)\nexport OPENROUTER_API_KEY="${apiKey}"\n`;
      await writeFile(envrcPath, envContent, { flag: 'a' });
      process.env.OPENROUTER_API_KEY = apiKey;

      return json({ success: true });
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'Failed to save API key' },
        { status: 500 }
      );
    }
  }

  // GitHub OAuth (using gh CLI)
  if (intent === "login" && provider === "github") {
    try {
      await execAsync('gh auth login', {
        timeout: 120000
      });
      return json({ success: true });
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'GitHub login failed' },
        { status: 500 }
      );
    }
  }

  // Codex/OpenAI API key
  if (intent === "set-api-key" && provider === "codex") {
    const apiKey = formData.get("apiKey") as string;

    if (!apiKey || !apiKey.startsWith('sk-')) {
      return json({ error: 'Invalid OpenAI API key (must start with sk-)' }, { status: 400 });
    }

    try {
      const envContent = `\n# OpenAI/Codex API Key (set via Nexus settings)\nexport OPENAI_API_KEY="${apiKey}"\n`;
      await writeFile(envrcPath, envContent, { flag: 'a' });
      process.env.OPENAI_API_KEY = apiKey;

      return json({ success: true });
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'Failed to save API key' },
        { status: 500 }
      );
    }
  }

  // Credential file path
  if (intent === "set-credentials-file") {
    const filePath = formData.get("filePath") as string;
    const envVar = formData.get("envVar") as string;

    if (!filePath || !envVar) {
      return json({ error: 'Missing file path or environment variable name' }, { status: 400 });
    }

    try {
      const envContent = `\n# Credentials file (set via Nexus settings)\nexport ${envVar}="${filePath}"\n`;
      await writeFile(envrcPath, envContent, { flag: 'a' });
      process.env[envVar] = filePath;

      return json({ success: true });
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'Failed to save credentials file path' },
        { status: 500 }
      );
    }
  }

  return json({ error: 'Invalid intent or provider' }, { status: 400 });
}

export default function SettingsPage() {
  const data = useLoaderData<typeof loader>();
  const fetcher = useFetcher<typeof action>();
  const projectsFetcher = useFetcher<typeof loader>();
  const [activeTab, setActiveTab] = useState<'google' | 'openrouter' | 'github' | 'codex'>('google');

  const loading = fetcher.state !== "idle" || projectsFetcher.state !== "idle";
  const projects = projectsFetcher.data?.providers.google.projects || data.providers.google.projects || [];

  function handleFetchProjects() {
    projectsFetcher.load("/settings?action=fetch-projects&provider=google");
  }

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-8">Settings - LLM Router</h1>

        {fetcher.data?.error && (
          <div className="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded mb-4">
            {fetcher.data.error}
          </div>
        )}

        {fetcher.data?.success && (
          <div className="bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded mb-4">
            Settings saved successfully!
          </div>
        )}

        {/* Provider Tabs */}
        <div className="bg-white rounded-lg shadow mb-6">
          <div className="border-b border-gray-200">
            <nav className="flex -mb-px">
              <button
                onClick={() => setActiveTab('google')}
                className={`px-6 py-3 border-b-2 font-medium ${
                  activeTab === 'google'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                Google Gemini {data.providers.google.authenticated && '✓'}
              </button>
              <button
                onClick={() => setActiveTab('openrouter')}
                className={`px-6 py-3 border-b-2 font-medium ${
                  activeTab === 'openrouter'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                OpenRouter {data.providers.openrouter.configured && '✓'}
              </button>
              <button
                onClick={() => setActiveTab('github')}
                className={`px-6 py-3 border-b-2 font-medium ${
                  activeTab === 'github'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                GitHub {data.providers.github.authenticated && '✓'}
              </button>
              <button
                onClick={() => setActiveTab('codex')}
                className={`px-6 py-3 border-b-2 font-medium ${
                  activeTab === 'codex'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                Codex/OpenAI {data.providers.codex.configured && '✓'}
              </button>
            </nav>
          </div>

          <div className="p-6">
            {/* Google Gemini Tab */}
            {activeTab === 'google' && (
              <div>
                <h2 className="text-xl font-semibold mb-4">Google Gemini Code Assist</h2>

                {!data.providers.google.authenticated ? (
                  <div>
                    <p className="text-gray-600 mb-4">
                      Connect your Google account to use Gemini Code Assist API (cloudcode-pa.googleapis.com)
                    </p>
                    <Form method="post">
                      <input type="hidden" name="intent" value="login" />
                      <input type="hidden" name="provider" value="google" />
                      <button
                        type="submit"
                        disabled={loading}
                        className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
                      >
                        {loading ? 'Logging in...' : 'Login with Google'}
                      </button>
                    </Form>
                  </div>
                ) : (
                  <div>
                    <div className="flex items-center justify-between mb-4">
                      <div>
                        <p className="text-green-600 font-medium">✓ Connected</p>
                        {data.providers.google.email && (
                          <p className="text-sm text-gray-600">{data.providers.google.email}</p>
                        )}
                      </div>
                      <button
                        onClick={handleFetchProjects}
                        disabled={loading}
                        className="text-blue-600 hover:text-blue-800"
                      >
                        {loading ? 'Loading...' : 'Refresh Projects'}
                      </button>
                    </div>

                    {/* Project Selection */}
                    <div className="border-t pt-4">
                      <h3 className="font-medium mb-3">Select Google Cloud Project</h3>
                      {projects.length === 0 ? (
                        <p className="text-gray-600 text-sm">
                          No projects loaded. <button onClick={handleFetchProjects} className="text-blue-600 hover:underline">Load projects</button>
                        </p>
                      ) : (
                        <div className="space-y-2">
                          {projects.map(project => (
                            <Form method="post" key={project.projectId}>
                              <input type="hidden" name="intent" value="set-project" />
                              <input type="hidden" name="provider" value="google" />
                              <input type="hidden" name="projectId" value={project.projectId} />
                              <button
                                type="submit"
                                className={`w-full text-left border rounded p-3 hover:bg-gray-50 ${
                                  data.providers.google.currentProject === project.projectId ? 'border-blue-500 bg-blue-50' : 'border-gray-200'
                                }`}
                              >
                                <div className="flex items-center justify-between">
                                  <div>
                                    <p className="font-medium">{project.displayName}</p>
                                    <p className="text-sm text-gray-600">Project ID: {project.projectId}</p>
                                  </div>
                                  {data.providers.google.currentProject === project.projectId && (
                                    <span className="text-blue-600 font-medium">✓ Active</span>
                                  )}
                                </div>
                              </button>
                            </Form>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                )}

                <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <h3 className="font-medium text-blue-900 mb-2">About Gemini Code Assist</h3>
                  <ul className="text-sm text-blue-800 space-y-1">
                    <li>• Uses cloudcode-pa.googleapis.com (Project Assistant API)</li>
                    <li>• FREE tier for code assistance (not billed)</li>
                    <li>• OAuth credentials shared with CLI (@google/gemini-cli)</li>
                    <li>• No gcloud SDK required - lightweight npm authentication</li>
                  </ul>
                </div>
              </div>
            )}

            {/* OpenRouter Tab */}
            {activeTab === 'openrouter' && (
              <div>
                <h2 className="text-xl font-semibold mb-4">OpenRouter</h2>

                {!data.providers.openrouter.configured ? (
                  <Form method="post">
                    <input type="hidden" name="intent" value="set-api-key" />
                    <input type="hidden" name="provider" value="openrouter" />
                    <div className="mb-4">
                      <label htmlFor="openrouter-key" className="block text-sm font-medium text-gray-700 mb-2">
                        API Key
                      </label>
                      <input
                        type="password"
                        id="openrouter-key"
                        name="apiKey"
                        placeholder="sk-or-v1-..."
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                      <p className="text-sm text-gray-500 mt-1">
                        Get your API key from <a href="https://openrouter.ai/keys" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">openrouter.ai/keys</a>
                      </p>
                    </div>
                    <button
                      type="submit"
                      disabled={loading}
                      className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
                    >
                      {loading ? 'Saving...' : 'Save API Key'}
                    </button>
                  </Form>
                ) : (
                  <div>
                    <p className="text-green-600 font-medium mb-4">✓ API Key Configured</p>
                    <Form method="post">
                      <input type="hidden" name="intent" value="set-api-key" />
                      <input type="hidden" name="provider" value="openrouter" />
                      <div className="mb-4">
                        <label htmlFor="openrouter-key-update" className="block text-sm font-medium text-gray-700 mb-2">
                          Update API Key
                        </label>
                        <input
                          type="password"
                          id="openrouter-key-update"
                          name="apiKey"
                          placeholder="sk-or-v1-..."
                          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      <button
                        type="submit"
                        disabled={loading}
                        className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
                      >
                        {loading ? 'Updating...' : 'Update API Key'}
                      </button>
                    </Form>
                  </div>
                )}

                <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <h3 className="font-medium text-blue-900 mb-2">About OpenRouter</h3>
                  <ul className="text-sm text-blue-800 space-y-1">
                    <li>• Access 100+ AI models through one API</li>
                    <li>• Pay-per-use pricing (typically $0.001-0.01 per 1K tokens)</li>
                    <li>• Free tier available for testing</li>
                    <li>• Supports Claude, GPT-4, Llama, and more</li>
                  </ul>
                </div>
              </div>
            )}

            {/* GitHub Tab */}
            {activeTab === 'github' && (
              <div>
                <h2 className="text-xl font-semibold mb-4">GitHub Copilot</h2>

                {!data.providers.github.authenticated ? (
                  <div>
                    <p className="text-gray-600 mb-4">
                      Login to GitHub to use Copilot API (requires active Copilot subscription)
                    </p>
                    <Form method="post">
                      <input type="hidden" name="intent" value="login" />
                      <input type="hidden" name="provider" value="github" />
                      <button
                        type="submit"
                        disabled={loading}
                        className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
                      >
                        {loading ? 'Logging in...' : 'Login with GitHub'}
                      </button>
                    </Form>
                  </div>
                ) : (
                  <div>
                    <p className="text-green-600 font-medium">✓ Connected</p>
                    {data.providers.github.username && (
                      <p className="text-sm text-gray-600">GitHub: @{data.providers.github.username}</p>
                    )}
                  </div>
                )}

                <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <h3 className="font-medium text-blue-900 mb-2">About GitHub Copilot</h3>
                  <ul className="text-sm text-blue-800 space-y-1">
                    <li>• Requires active GitHub Copilot subscription</li>
                    <li>• Uses gh CLI for authentication</li>
                    <li>• Access to GPT-4 and GPT-3.5 models</li>
                    <li>• Subscription-based (not pay-per-use)</li>
                  </ul>
                </div>
              </div>
            )}

            {/* Codex/OpenAI Tab */}
            {activeTab === 'codex' && (
              <div>
                <h2 className="text-xl font-semibold mb-4">Codex / OpenAI</h2>

                {!data.providers.codex.configured ? (
                  <Form method="post">
                    <input type="hidden" name="intent" value="set-api-key" />
                    <input type="hidden" name="provider" value="codex" />
                    <div className="mb-4">
                      <label htmlFor="openai-key" className="block text-sm font-medium text-gray-700 mb-2">
                        API Key
                      </label>
                      <input
                        type="password"
                        id="openai-key"
                        name="apiKey"
                        placeholder="sk-..."
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                      <p className="text-sm text-gray-500 mt-1">
                        Get your API key from <a href="https://platform.openai.com/api-keys" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">platform.openai.com/api-keys</a>
                      </p>
                    </div>
                    <button
                      type="submit"
                      disabled={loading}
                      className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
                    >
                      {loading ? 'Saving...' : 'Save API Key'}
                    </button>
                  </Form>
                ) : (
                  <div>
                    <p className="text-green-600 font-medium mb-4">✓ API Key Configured</p>
                    <Form method="post">
                      <input type="hidden" name="intent" value="set-api-key" />
                      <input type="hidden" name="provider" value="codex" />
                      <div className="mb-4">
                        <label htmlFor="openai-key-update" className="block text-sm font-medium text-gray-700 mb-2">
                          Update API Key
                        </label>
                        <input
                          type="password"
                          id="openai-key-update"
                          name="apiKey"
                          placeholder="sk-..."
                          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      <button
                        type="submit"
                        disabled={loading}
                        className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
                      >
                        {loading ? 'Updating...' : 'Update API Key'}
                      </button>
                    </Form>
                  </div>
                )}

                <div className="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                  <h3 className="font-medium text-yellow-900 mb-2">⚠️ Warning: Pay-per-use API</h3>
                  <ul className="text-sm text-yellow-800 space-y-1">
                    <li>• This is a PAY-PER-USE API (not subscription)</li>
                    <li>• GPT-4 costs ~$0.03-0.12 per 1K tokens</li>
                    <li>• Consider using subscription-based providers for cost control</li>
                    <li>• Only recommended if you have specific OpenAI requirements</li>
                  </ul>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Credential Files Section */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold mb-4">Credential Files</h2>
          <p className="text-gray-600 mb-4">
            Specify custom credential file paths for providers that support file-based authentication.
          </p>

          <Form method="post">
            <input type="hidden" name="intent" value="set-credentials-file" />
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div>
                <label htmlFor="env-var" className="block text-sm font-medium text-gray-700 mb-2">
                  Environment Variable
                </label>
                <input
                  type="text"
                  id="env-var"
                  name="envVar"
                  placeholder="GOOGLE_APPLICATION_CREDENTIALS"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label htmlFor="file-path" className="block text-sm font-medium text-gray-700 mb-2">
                  File Path
                </label>
                <input
                  type="text"
                  id="file-path"
                  name="filePath"
                  placeholder="/path/to/credentials.json"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
            </div>
            <button
              type="submit"
              disabled={loading}
              className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
            >
              {loading ? 'Saving...' : 'Save Credential File'}
            </button>
          </Form>
        </div>
      </div>
    </div>
  );
}
