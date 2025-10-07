/**
 * Heuristic-based capability scorer
 *
 * Quickly scores models based on naming patterns and known characteristics
 * Much faster than LLM analysis, good baseline scores
 */

interface ModelCapabilityScore {
  code: number;
  reasoning: number;
  creativity: number;
  speed: number;
  cost: number;
  confidence: 'high' | 'medium' | 'low';
  reasoning_text: string;
}

export function scoreModelByHeuristics(model: any): ModelCapabilityScore {
  const id = model.id.toLowerCase();
  const name = (model.displayName || model.id).toLowerCase();
  const description = (model.description || '').toLowerCase();
  const cost = model.cost || 'unknown';

  let code = 7;
  let reasoning = 7;
  let creativity = 6;
  let speed = 7;
  let costScore = 5;
  let confidence: 'high' | 'medium' | 'low' = 'medium';
  let reasoningText = 'Heuristic-based scoring';

  // Cost scoring (based on model.cost field)
  if (cost === 'free') {
    costScore = 10;  // FREE unlimited
  } else if (cost === 'limited') {
    costScore = 5;   // Quota-limited
  } else {
    costScore = 1;   // Pay-per-use
  }

  // Claude models
  if (id.includes('claude')) {
    if (id.includes('opus')) {
      code = 9; reasoning = 10; creativity = 10; speed = 4;
      confidence = 'high';
      reasoningText = 'Claude Opus: Known for best reasoning + creativity, slower';
    } else if (id.includes('sonnet-4.5') || id.includes('sonnet-4')) {
      code = 9; reasoning = 10; creativity = 9; speed = 6;
      confidence = 'high';
      reasoningText = 'Claude Sonnet 4.x: Top-tier reasoning + code quality';
    } else if (id.includes('sonnet')) {
      code = 8; reasoning = 9; creativity = 8; speed = 7;
      confidence = 'high';
      reasoningText = 'Claude Sonnet 3.x: Strong all-around performance';
    } else if (id.includes('haiku')) {
      code = 7; reasoning = 7; creativity = 6; speed = 9;
      confidence = 'high';
      reasoningText = 'Claude Haiku: Fast, good for simple tasks';
    }
  }

  // Gemini models
  else if (id.includes('gemini')) {
    if (id.includes('pro') || id.includes('2.5-pro')) {
      code = 8; reasoning = 9; creativity = 8; speed = 7;
      confidence = 'high';
      reasoningText = 'Gemini Pro: Strong reasoning, FREE via ADC';
    } else if (id.includes('flash')) {
      code = 7; reasoning = 7; creativity = 6; speed = 10;
      confidence = 'high';
      reasoningText = 'Gemini Flash: Fastest, FREE unlimited';
    }
  }

  // GPT models (OpenAI via Codex/Copilot)
  else if (id.includes('gpt')) {
    if (id.includes('gpt-5') && !id.includes('mini')) {
      code = 9; reasoning = 8; creativity = 7; speed = 7;
      confidence = 'medium';
      reasoningText = 'GPT-5: Expected strong code quality';
    } else if (id.includes('gpt-4o')) {
      code = 8; reasoning = 8; creativity = 7; speed = 8;
      confidence = 'high';
      reasoningText = 'GPT-4o: Well-balanced, FREE via Copilot';
    } else if (id.includes('gpt-4')) {
      code = 7; reasoning = 7; creativity = 6; speed = 7;
      confidence = 'medium';
      reasoningText = 'GPT-4.x: Solid performance';
    } else if (id.includes('mini') || id.includes('nano')) {
      code = 6; reasoning = 6; creativity = 5; speed = 10;
      confidence = 'medium';
      reasoningText = 'Mini/Nano model: Fast, basic capability';
    }
  }

  // O-series models (reasoning-focused)
  else if (id.includes('o1') || id.includes('o3') || id.includes('o4')) {
    code = 8; reasoning = 9; creativity = 6; speed = 6;
    confidence = 'medium';
    reasoningText = 'O-series: Strong reasoning models';
  }

  // Grok models
  else if (id.includes('grok')) {
    if (id.includes('fast') || id.includes('code-fast')) {
      code = 8; reasoning = 7; creativity = 6; speed = 9;
      confidence = 'medium';
      reasoningText = 'Grok Fast: Fast code generation';
    } else {
      code = 7; reasoning = 8; creativity = 7; speed = 6;
      confidence = 'medium';
      reasoningText = 'Grok: Alternative reasoning perspective';
    }
  }

  // DeepSeek models
  else if (id.includes('deepseek')) {
    code = 8; reasoning = 9; creativity = 7; speed = 7;
    confidence = 'medium';
    reasoningText = 'DeepSeek: Strong reasoning, open source';
  }

  // Cursor models
  else if (id.includes('cursor')) {
    if (id.includes('cheetah')) {
      code = 7; reasoning = 7; creativity = 6; speed = 10;
      confidence = 'high';
      reasoningText = 'Cursor Cheetah: Mystery fast model, FREE unlimited';
    } else if (id.includes('auto')) {
      code = 7; reasoning = 7; creativity = 6; speed = 8;
      confidence = 'medium';
      reasoningText = 'Cursor Auto: Automatic model selection';
    }
  }

  // Codestral/Mistral code models
  else if (id.includes('codestral') || (id.includes('mistral') && id.includes('code'))) {
    code = 9; reasoning = 7; creativity = 6; speed = 8;
    confidence = 'medium';
    reasoningText = 'Code-specialized model';
  }

  // Generic Mistral
  else if (id.includes('mistral')) {
    if (id.includes('large')) {
      code = 7; reasoning = 8; creativity = 7; speed = 6;
    } else if (id.includes('small') || id.includes('mini')) {
      code = 6; reasoning = 6; creativity = 5; speed = 9;
    } else {
      code = 7; reasoning = 7; creativity = 6; speed = 7;
    }
    confidence = 'medium';
    reasoningText = 'Mistral family model';
  }

  // Llama models
  else if (id.includes('llama')) {
    if (id.includes('405b') || id.includes('70b')) {
      code = 7; reasoning = 8; creativity = 7; speed = 5;
      confidence = 'medium';
      reasoningText = 'Large Llama model: Strong reasoning, slower';
    } else {
      code = 6; reasoning = 6; creativity = 6; speed = 8;
      confidence = 'medium';
      reasoningText = 'Llama model: Open source';
    }
  }

  // Phi models (Microsoft)
  else if (id.includes('phi')) {
    code = 7; reasoning = 7; creativity = 6; speed = 9;
    confidence = 'medium';
    reasoningText = 'Microsoft Phi: Fast, efficient small model';
  }

  // Cohere models
  else if (id.includes('cohere')) {
    code = 6; reasoning = 7; creativity = 6; speed = 7;
    confidence = 'low';
    reasoningText = 'Cohere model: General purpose';
  }

  // AI21 Jamba
  else if (id.includes('jamba')) {
    code = 6; reasoning = 7; creativity = 6; speed = 8;
    confidence = 'low';
    reasoningText = 'AI21 Jamba: Hybrid architecture';
  }

  // Embedding models (not for generation)
  else if (id.includes('embedding') || id.includes('embed')) {
    code = 0; reasoning = 0; creativity = 0; speed = 10; costScore = 10;
    confidence = 'high';
    reasoningText = 'Embedding model: Not for text generation';
  }

  return {
    code,
    reasoning,
    creativity,
    speed,
    cost: costScore,
    confidence,
    reasoning_text: reasoningText
  };
}
