import { useApprovalWebSocket, type ApprovalRequest, type QuestionRequest } from '../hooks/useApprovalWebSocket';
import { ApprovalCard } from './ApprovalCard';
import { QuestionCard } from './QuestionCard';

/**
 * Main component for displaying all approval/question requests
 */
export function ApprovalCardsContainer() {
  const { requests, connected, error, respondToApproval, respondToQuestion } = useApprovalWebSocket();

  if (!connected && requests.length === 0) {
    return (
      <div className="text-xs text-gray-500 italic p-2">
        {error ? `Connection error: ${error}` : 'Connecting to approval bridge...'}
      </div>
    );
  }

  if (requests.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-col gap-1">
      {requests.map((request) => {
        if (request.type === 'approval') {
          const approval = request as ApprovalRequest;
          return (
            <ApprovalCard
              key={approval.id}
              request={approval}
              onApprove={() => respondToApproval(approval.id, true)}
              onReject={() => respondToApproval(approval.id, false)}
            />
          );
        } else if (request.type === 'question') {
          const question = request as QuestionRequest;
          return (
            <QuestionCard
              key={question.id}
              request={question}
              onRespond={(response) => respondToQuestion(question.id, response)}
            />
          );
        }
        return null;
      })}
    </div>
  );
}

export default ApprovalCardsContainer;
