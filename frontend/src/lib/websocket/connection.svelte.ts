export type ConnectionState = 'connecting' | 'connected' | 'disconnected' | 'error' | 'polling';

export type WebSocketMessage = {
	type: 'feed_update' | 'heartbeat';
	timestamp: number;
};

export function createLiveConnection(
	onUpdate: (timestamp: number) => void,
	onFallbackToPolling?: () => void,
	onRecoveredFromPolling?: () => void
) {
	let ws: WebSocket | null = null;
	let reconnectAttempts = 0;
	let consecutiveFailures = 0;
	let usePollingFallback = false;
	const maxReconnectDelay = 30000;
	const maxConsecutiveFailures = 5;

	const state = $state<ConnectionState>('disconnected');

	function connect() {
		if (usePollingFallback) {
			return;
		}

		state = 'connecting';

		const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
		const wsUrl = `${protocol}//${window.location.host}/api/ws`;

		ws = new WebSocket(wsUrl);

		ws.onopen = () => {
			state = 'connected';
			reconnectAttempts = 0;
			consecutiveFailures = 0;

			if (usePollingFallback) {
				usePollingFallback = false;
				state = 'connected';
				console.log('[WebSocket] Recovered from polling fallback');
				onRecoveredFromPolling?.();
			}

			console.log('[WebSocket] Connected');
		};

		ws.onmessage = (event) => {
			try {
				const data: WebSocketMessage = JSON.parse(event.data);

				if (data.type === 'feed_update') {
					console.log('[WebSocket] Feed update received:', data.timestamp);
					onUpdate(data.timestamp);
				} else if (data.type === 'heartbeat') {
					// Keep-alive, no action needed
				}
			} catch (e) {
				console.error('[WebSocket] Failed to parse message:', e);
			}
		};

		ws.onerror = (error) => {
			console.error('[WebSocket] Error:', error);
			state = 'error';
		};

		ws.onclose = () => {
			state = 'disconnected';
			console.log('[WebSocket] Disconnected');
			ws = null;

			consecutiveFailures++;

			if (consecutiveFailures >= maxConsecutiveFailures && !usePollingFallback) {
				usePollingFallback = true;
				state = 'polling';
				console.warn(`[WebSocket] Falling back to polling after ${consecutiveFailures} consecutive failures`);
				onFallbackToPolling?.();
				return;
			}

			// Exponential backoff with jitter
			const baseDelay = Math.min(1000 * Math.pow(2, reconnectAttempts), maxReconnectDelay);
			const jitter = 0.5 + Math.random(); // 0.5 to 1.5 multiplier
			const delay = Math.floor(baseDelay * jitter);
			reconnectAttempts++;

			console.log(`[WebSocket] Reconnecting in ${delay}ms (attempt ${reconnectAttempts}, failures: ${consecutiveFailures})`);
			setTimeout(connect, delay);
		};
	}

	function disconnect() {
		if (ws) {
			ws.close();
			ws = null;
		}
		usePollingFallback = false;
		consecutiveFailures = 0;
		state = 'disconnected';
	}

	function forceReconnect() {
		consecutiveFailures = 0;
		usePollingFallback = false;
		connect();
	}

	return {
		get state() {
			return state;
		},
		get isUsingPolling() {
			return usePollingFallback;
		},
		connect,
		disconnect,
		forceReconnect
	};
}
