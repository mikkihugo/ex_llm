import { useState } from 'react';
import type { ApprovalRequest } from '../hooks/useApprovalWebSocket';

interface ApprovalCardProps {
  request: ApprovalRequest;
  onApprove: () => void;
  onReject: () => void;
}

export function ApprovalCard({ request, onApprove, onReject }: ApprovalCardProps) {
  const [isProcessing, setIsProcessing] = useState(false);

  const handleApprove = async () => {
    setIsProcessing(true);
    onApprove();
    setIsProcessing(false);
  };

  const handleReject = async () => {
    setIsProcessing(true);
    onReject();
    setIsProcessing(false);
  };

  return (
    <div className="flex flex-col gap-3 p-4 rounded-lg border border-amber-500 bg-amber-950/50 my-4">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3 className="font-semibold text-amber-200 mb-1">Code Approval Requested</h3>
          <p className="text-sm text-gray-400 mb-2">
            <span className="font-mono text-amber-100">{request.file_path}</span>
          </p>
          <p className="text-sm text-gray-300 mb-3">{request.description}</p>
        </div>
        <span className="text-xs text-gray-500 whitespace-nowrap ml-2">
          {new Date(request.timestamp).toLocaleTimeString()}
        </span>
      </div>

      {/* Diff preview */}
      <div className="bg-gray-900/50 rounded border border-gray-700 p-3 max-h-48 overflow-y-auto">
        <pre className="text-xs font-mono text-gray-300 whitespace-pre-wrap break-words">
          {request.diff}
        </pre>
      </div>

      {/* Buttons */}
      <div className="flex gap-2 justify-end">
        <button
          onClick={handleReject}
          disabled={isProcessing}
          className="px-4 py-2 rounded bg-red-600 hover:bg-red-700 disabled:opacity-50 text-sm font-medium text-white transition-colors"
        >
          {isProcessing ? 'Processing...' : 'Reject'}
        </button>
        <button
          onClick={handleApprove}
          disabled={isProcessing}
          className="px-4 py-2 rounded bg-green-600 hover:bg-green-700 disabled:opacity-50 text-sm font-medium text-white transition-colors"
        >
          {isProcessing ? 'Processing...' : 'Approve'}
        </button>
      </div>

      {/* Agent info */}
      <p className="text-xs text-gray-500">
        From: <span className="text-gray-400">{request.agent_id}</span>
      </p>
    </div>
  );
}
