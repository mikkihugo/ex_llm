import { useEffect, useState, useCallback, useRef } from 'react';

export interface ApprovalRequest {
  id: string;
  type: 'approval';
  agent_id: string;
  timestamp: string;
  file_path: string;
  diff: string;
  description: string;
}

export interface QuestionRequest {
  id: string;
  type: 'question';
  agent_id: string;
  timestamp: string;
  question: string;
  context?: Record<string, unknown>;
}

export type HitlRequest = ApprovalRequest | QuestionRequest;

export interface UseApprovalWebSocketReturn {
  requests: HitlRequest[];
  connected: boolean;
  error: string | null;
  respondToApproval: (id: string, approved: boolean) => void;
  respondToQuestion: (id: string, response: string) => void;
}

export function useApprovalWebSocket(): UseApprovalWebSocketReturn {
  const [requests, setRequests] = useState<HitlRequest[]>([]);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const connectWebSocket = useCallback(() => {
    try {
      const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
      const host = window.location.host;
      const ws = new WebSocket(`${protocol}://${host}/ws/approval`);

      ws.onopen = () => {
        console.log('[useApprovalWebSocket] Connected to approval bridge');
        setConnected(true);
        setError(null);
      };

      ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data);

          if (message.type === 'connected') {
            console.log(`[useApprovalWebSocket] Bridge connected, ${message.clientCount} clients`);
          } else if (message.type === 'request') {
            const data = message.data;
            const request: HitlRequest =
              data.requestType === 'approval'
                ? {
                    id: data.id,
                    type: 'approval',
                    agent_id: data.agentId,
                    timestamp: data.timestamp,
                    file_path: data.filePath,
                    diff: data.diff,
                    description: data.description,
                  }
                : {
                    id: data.id,
                    type: 'question',
                    agent_id: data.agentId,
                    timestamp: data.timestamp,
                    question: data.question,
                    context: data.context,
                  };

            setRequests((prev) => [request, ...prev]);
          } else if (message.type === 'response_received') {
            // Remove request from list after response is sent
            setRequests((prev) => prev.filter((r) => r.id !== message.requestId));
          }
        } catch (err) {
          console.error('[useApprovalWebSocket] Error parsing message:', err);
        }
      };

      ws.onerror = (event) => {
        console.error('[useApprovalWebSocket] WebSocket error:', event);
        setError('WebSocket error');
        setConnected(false);
      };

      ws.onclose = () => {
        console.log('[useApprovalWebSocket] WebSocket closed, reconnecting in 3s...');
        setConnected(false);
        wsRef.current = null;

        // Reconnect after 3 seconds
        reconnectTimeoutRef.current = setTimeout(() => {
          connectWebSocket();
        }, 3000);
      };

      wsRef.current = ws;
    } catch (err) {
      console.error('[useApprovalWebSocket] Connection error:', err);
      setError(String(err));
      setConnected(false);
    }
  }, []);

  useEffect(() => {
    connectWebSocket();

    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
  }, [connectWebSocket]);

  const respondToApproval = useCallback((id: string, approved: boolean) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(
        JSON.stringify({
          requestId: id,
          type: 'approval',
          approved,
        }),
      );
    } else {
      console.error('[useApprovalWebSocket] WebSocket not connected');
    }
  }, []);

  const respondToQuestion = useCallback((id: string, response: string) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(
        JSON.stringify({
          requestId: id,
          type: 'question',
          response,
        }),
      );
    } else {
      console.error('[useApprovalWebSocket] WebSocket not connected');
    }
  }, []);

  return {
    requests,
    connected,
    error,
    respondToApproval,
    respondToQuestion,
  };
}
