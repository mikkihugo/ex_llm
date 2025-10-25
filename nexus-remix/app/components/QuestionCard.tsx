import { useState } from 'react';
import type { QuestionRequest } from '../hooks/useApprovalWebSocket';

interface QuestionCardProps {
  request: QuestionRequest;
  onRespond: (response: string) => void;
}

export function QuestionCard({ request, onRespond }: QuestionCardProps) {
  const [answer, setAnswer] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [suggestedAnswer, setSuggestedAnswer] = useState<string | null>(null);
  const [isSuggestingAnswer, setIsSuggestingAnswer] = useState(false);

  const handleSubmit = async () => {
    if (!answer.trim()) return;

    setIsProcessing(true);
    onRespond(answer);
    setAnswer('');
    setSuggestedAnswer(null);
    setIsProcessing(false);
  };

  const requestLLMSuggestion = async () => {
    setIsSuggestingAnswer(true);
    try {
      // Optional: Use LLM to suggest an answer for human review
      // This is NOT automatic - human always decides
      // For now, this is a placeholder. Can be implemented later with:
      // const response = await fetch('/api/suggest-answer', { ... })
      setSuggestedAnswer('(LLM suggestion feature coming soon)');
    } catch (err) {
      console.error('Error getting suggestion:', err);
    } finally {
      setIsSuggestingAnswer(false);
    }
  };

  return (
    <div className="flex flex-col gap-3 p-4 rounded-lg border border-blue-500 bg-blue-950/50 my-4">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="font-semibold text-blue-200 mb-1">Question from Agent</h3>
          <p className="text-sm text-gray-400">
            <span className="text-gray-300">{request.agent_id}</span>
          </p>
        </div>
        <span className="text-xs text-gray-500 whitespace-nowrap ml-2">
          {new Date(request.timestamp).toLocaleTimeString()}
        </span>
      </div>

      {/* Question */}
      <div className="bg-gray-900/50 rounded border border-gray-700 p-3">
        <p className="text-sm text-gray-200">{request.question}</p>
      </div>

      {/* Context if available */}
      {request.context && Object.keys(request.context).length > 0 && (
        <div className="bg-gray-900/50 rounded border border-gray-700 p-3 max-h-40 overflow-y-auto">
          <p className="text-xs text-gray-400 mb-2">Context:</p>
          <pre className="text-xs font-mono text-gray-300 whitespace-pre-wrap break-words">
            {JSON.stringify(request.context, null, 2)}
          </pre>
        </div>
      )}

      {/* LLM Suggestion (optional) */}
      {suggestedAnswer && (
        <div className="bg-green-900/30 rounded border border-green-700 p-3">
          <div className="flex items-start justify-between mb-2">
            <p className="text-xs text-green-400 font-semibold">💡 AI Suggestion (for your review)</p>
            <button
              onClick={() => setSuggestedAnswer(null)}
              className="text-xs text-green-400 hover:text-green-300"
            >
              Dismiss
            </button>
          </div>
          <p className="text-sm text-gray-200">{suggestedAnswer}</p>
          <button
            onClick={() => {
              setAnswer(suggestedAnswer);
              setSuggestedAnswer(null);
            }}
            className="mt-2 text-xs px-2 py-1 rounded bg-green-600 hover:bg-green-700 text-white transition-colors"
          >
            Use This Answer
          </button>
        </div>
      )}

      {/* Response input */}
      <div className="flex flex-col gap-2">
        <div className="flex gap-2">
          <input
            type="text"
            value={answer}
            onChange={(e) => setAnswer(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !isProcessing && handleSubmit()}
            placeholder="Type your answer..."
            disabled={isProcessing || isSuggestingAnswer}
            className="flex-1 px-3 py-2 rounded bg-gray-900 border border-gray-700 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 disabled:opacity-50"
          />
          <button
            onClick={requestLLMSuggestion}
            disabled={isSuggestingAnswer || isProcessing}
            title="Get LLM assistance (optional)"
            className="px-3 py-2 rounded bg-green-600 hover:bg-green-700 disabled:opacity-50 text-sm font-medium text-white transition-colors"
          >
            {isSuggestingAnswer ? '⏳' : '💡'}
          </button>
          <button
            onClick={handleSubmit}
            disabled={isProcessing || !answer.trim()}
            className="px-4 py-2 rounded bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-sm font-medium text-white transition-colors"
          >
            {isProcessing ? 'Sending...' : 'Answer'}
          </button>
        </div>
      </div>
    </div>
  );
}
