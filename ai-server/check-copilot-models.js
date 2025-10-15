import { getCopilotAccessToken } from './src/github-copilot-oauth.ts';

const token = await getCopilotAccessToken();
if (!token) {
  console.error('No Copilot token');
  process.exit(1);
}

const res = await fetch('https://api.githubcopilot.com/models', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'editor-version': 'vscode/1.99.3',
    'editor-plugin-version': 'copilot-chat/0.26.7',
    'user-agent': 'GitHubCopilotChat/0.26.7'
  }
});

const data = await res.json();
console.log('\n=== ACTUAL GITHUB COPILOT MODELS ===\n');

const chatModels = data.data?.filter(m => m.capabilities?.type === 'chat' && m.model_picker_enabled) || [];

chatModels.forEach(m => {
  console.log(`ID: ${m.id}`);
  console.log(`  Name: ${m.name}`);
  console.log(`  Context: ${(m.capabilities.limits.max_context_window_tokens/1000).toFixed(0)}K`);
  console.log(`  Vision: ${m.capabilities.supports.vision || false}`);
  console.log('');
});

console.log(`Total: ${chatModels.length} models\n`);
