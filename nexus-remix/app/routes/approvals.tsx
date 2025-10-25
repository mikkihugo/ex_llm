import { useRef, useEffect } from 'react';
import { ApprovalCardsContainer } from '~/components/ApprovalCardsContainer';

/**
 * Approvals & Questions route - HITL Control Panel
 *
 * Shows agent approval/question requests for human review/decision.
 * Humans approve code changes and answer agent questions.
 * Can be AI-assisted (LLM suggests answers for review).
 */
export default function ApprovalsRoute() {
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, []);

  return (
    <div className="flex flex-col h-[600px] bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
      {/* Header */}
      <div className="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <h2 className="text-lg font-semibold text-white">Human-in-the-Loop Control Panel</h2>
        <p className="text-sm text-gray-400 mt-1">
          Review and approve/reject agent requests. Agents are waiting for your decisions.
        </p>
      </div>

      {/* Approval/Question Requests */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-6 py-4 space-y-3">
        <ApprovalCardsContainer />
      </div>

      {/* Status Bar */}
      <div className="border-t border-gray-700 bg-gray-800/50 px-6 py-3 text-xs text-gray-400">
        <p>
          💡 <span className="text-gray-300">Tip:</span> Use LLM assistance for complex decisions by clicking the 💡 button on question cards
        </p>
      </div>
    </div>
  );
}
