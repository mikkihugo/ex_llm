# Web Search Strategy for AI Providers

## 🔍 Native Web Search Capabilities (2025)

### **TIER 1: Native Web Search Built-In** ✅

These providers have **native web search** - no need for external tools:

#### 1. **ChatGPT 5 Pro** (openai-codex)
- **Has Web Search**: ✅ YES - Built into GPT-5
- **How it works**: Automatic search integration with reasoning
- **Quality**: 45% fewer factual errors with search enabled
- **Features**:
  - Multi-step search (searches, reasons, then follow-up searches)
  - Citations included
  - Works in "thinking" mode (80% fewer errors)
- **Activation**: Automatic when enabled in ChatGPT settings
- **Best for**: Research tasks, fact-checking, current events

#### 2. **Claude Max** (claude-code)
- **Has Web Search**: ✅ YES - "Research" feature (March 2025+)
- **Models**: Claude 3.7 Sonnet
- **How it works**: Toggle "web search" in profile settings
- **Features**:
  - Real-time information (beyond Oct 2024 cutoff)
  - Direct citations for fact-checking
  - Available to all paid users (Max, Team, Enterprise)
- **Activation**: Toggle in Claude settings
- **Best for**: Up-to-date answers with verifiable sources

#### 3. **Gemini Code Assist Professional** (gemini-code)
- **Has Web Search**: ✅ YES - "Grounding with Google Search"
- **How it works**: Available via Gemini API/AI Studio
- **Features**:
  - Connects to real-time web content
  - Grounding sources and search suggestions
  - Analyzes prompt → generates search queries → formulates grounded response
- **Note**: Code Assist primarily uses **LOCAL codebase grounding**, but web search available as separate feature
- **Activation**: Enable in API/AI Studio
- **Best for**: Accurate, fresh responses with Google Search backing

#### 4. **GitHub Copilot Enterprise** (github-copilot-free & github-copilot-premium)
- **Has Web Search**: ✅ YES - Bing integration
- **Availability**: All plans (Pro, Business, Enterprise)
- **How it works**: Enable "Copilot Access to Bing" policy in settings
- **Features**:
  - Answers tech questions with up-to-date info
  - References link shows search results used
  - Works in VS Code, Visual Studio, github.com
- **Activation**: Enable in Copilot Settings
- **Best for**: Tech-related questions within coding workflow

---

### **TIER 2: NO Native Web Search** ❌

#### 5. **GitHub Models** (github-models)
- **Has Web Search**: ❌ NO
- **Why**: Free tier models don't include web search
- **Workaround**: Must provide web search as external tool
- **Strategy**: Use as LLM for A/B testing, provide search results as context

---

## 🎯 Strategy: When to Use Web Search

### **Use Web Search For:**
1. **Current events** (after model's knowledge cutoff)
2. **Fact-checking** (verifying claims, statistics)
3. **Research tasks** (gathering up-to-date information)
4. **API documentation** (latest versions, breaking changes)
5. **Package versions** (latest releases, compatibility)
6. **Error messages** (searching for solutions)

### **Don't Need Web Search For:**
1. **Code generation** (most patterns are timeless)
2. **Refactoring** (based on existing code)
3. **Debugging** (analyzing local code)
4. **Architecture** (general principles)
5. **Testing** (writing tests for existing code)

---

## 🔧 Implementation Strategy

### **Option 1: Use Native Search (Preferred)**

When web search is needed, **prefer providers with native search**:

```
1. ChatGPT 5 Pro (best multi-step search)
2. Claude Max (best citations)
3. Gemini Pro (best Google Search integration)
4. Copilot Enterprise (best for coding context)
```

**Advantages:**
- No extra API calls
- Integrated reasoning + search
- Automatic citation management
- Better quality (models trained for search integration)

### **Option 2: External Tool (Fallback)**

For providers **WITHOUT native search** (GitHub Models), provide search as tool:

```typescript
// When using GitHub Models, offer web search tool
const tools = [
  {
    name: 'web_search',
    description: 'Search the web for current information',
    parameters: {
      query: { type: 'string', description: 'Search query' }
    }
  }
];

// When tool is called, use a provider WITH search:
async function handleWebSearch(query: string) {
  // Use ChatGPT 5, Claude, or Gemini to perform search
  // Return results as context to GitHub Models
}
```

**Advantages:**
- Works with any LLM
- Can use best search provider
- Explicit control over search calls

**Disadvantages:**
- Extra API calls (2 providers: 1 for search, 1 for reasoning)
- Manual citation handling
- Less integrated reasoning

---

## 💡 Routing Logic

### **When User Needs Web Search:**

```typescript
// Pseudocode for routing
if (requestNeedsWebSearch) {
  // Prefer Tier 1 providers with native search
  const providersWithSearch = [
    'openai-codex',      // GPT-5 (best multi-step)
    'claude-code',       // Claude (best citations)
    'gemini-code',       // Gemini (best Google integration)
    'github-copilot-*'   // Copilot (best for code)
  ];

  return selectFromPriority(providersWithSearch);
}

// If using GitHub Models (no native search)
if (provider === 'github-models' && needsWebSearch) {
  // Use external search tool
  // Call ChatGPT/Claude/Gemini for search
  // Pass results as context to GitHub Models
}
```

### **Automatic Detection:**

Detect if request needs web search based on:
- Keywords: "latest", "current", "recent", "today", "2025"
- Questions about: "what's new", "breaking changes", "recent versions"
- Error messages with version numbers
- API documentation requests

---

## 📊 Provider Comparison

| Provider | Native Search | Quality | Best For |
|----------|---------------|---------|----------|
| **ChatGPT 5 Pro** | ✅ Yes | 🟢 Excellent (80% fewer errors) | Multi-step research |
| **Claude Max** | ✅ Yes | 🟢 Excellent | Citations & fact-checking |
| **Gemini Pro** | ✅ Yes | 🟢 Excellent | Google Search integration |
| **Copilot Enterprise** | ✅ Yes (Bing) | 🟡 Good | Tech questions in IDE |
| **GitHub Models** | ❌ No | ⚪ N/A | Use external tool |

---

## ⚙️ Configuration

### **Enable Web Search:**

1. **ChatGPT Pro**: Settings → Beta Features → Web browsing ✅
2. **Claude Max**: Profile → Toggle "web search" ✅
3. **Gemini Pro**: AI Studio → Grounding with Google Search ✅
4. **Copilot**: Settings → "Copilot Access to Bing" ✅
5. **GitHub Models**: Implement external search tool

---

## 🎮 Recommendations

### **Your Setup (All have native search!):**

✅ ChatGPT 5 Pro - **Native search** (best reasoning + search)
✅ Claude Max - **Native search** (best citations)
✅ Gemini Professional - **Native search** (best Google)
✅ Copilot Enterprise - **Native search** (Bing)
❌ GitHub Models - **No search** (external tool needed)

### **Best Practices:**

1. **Don't strip native search** - it makes models better!
   - 45-80% fewer factual errors with search
   - Better at current information
   - Automatic citations

2. **Use search-enabled providers for:**
   - Research tasks
   - Documentation lookups
   - Version checking
   - Error debugging

3. **For GitHub Models (no search):**
   - Use for A/B testing (doesn't need current info)
   - Provide search as external tool if needed
   - Use Tier 1 providers for search, pass results as context

4. **Cost**: All native search is **FREE** within your subscriptions!
   - ChatGPT Pro: Included
   - Claude Max: Included
   - Gemini Pro: Included
   - Copilot: Included

---

## 🚀 Implementation Plan

### **Phase 1: Metadata (Done)**
- Add `webSearch: boolean` to provider capabilities
- Track which providers have native search

### **Phase 2: Smart Routing**
- Detect when requests need web search
- Prefer providers with native search
- Fall back to external tool for GitHub Models

### **Phase 3: External Tool (Optional)**
- Implement `web_search` tool for GitHub Models
- Use ChatGPT/Claude/Gemini as search backend
- Pass results as context

---

**Bottom Line:**
- ✅ **Keep native search enabled** - it makes models better!
- ✅ **4 out of 5 providers have search** - very good coverage
- ✅ **All included in subscriptions** - no extra cost
- ✅ **Only GitHub Models needs external tool** - implement if using for research

**Answer to your question:** NO, don't strip web search! Keep it enabled on providers that have it. For GitHub Models (the only one without), provide search as an external tool that calls one of your search-enabled providers.
