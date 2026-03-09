export type ConnectionState = 'connecting' | 'connected' | 'disconnected';

export type WebSocketMessage = {
	type: 'feed_update' | 'heartbeat' | 'clustering_status';
	timestamp: number;
	is_clustering?: boolean;
};

// Shared WebSocket connection instance
let sharedConnection: WebSocket | null = null;
let sharedState: ConnectionState = 'disconnected';
let reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
let intentionalClose = false;

// Exponential backoff state
const INITIAL_DELAY_MS = 1000;
const MAX_DELAY_MS = 30000;
const DELAY_MULTIPLIER = 2;
let currentDelayMs = INITIAL_DELAY_MS;

// Message queue for offline buffering
const messageQueue: WebSocketMessage[] = [];
const MAX_QUEUE_SIZE = 100;

// Event listeners for WebSocket messages
const listeners = new Set<(message: WebSocketMessage) => void>();

function flushMessageQueue() {
	while (messageQueue.length > 0) {
		const message = messageQueue.shift();
		if (message) {
			listeners.forEach(listener => listener(message));
		}
	}
}

function queueMessage(message: WebSocketMessage) {
	if (messageQueue.length < MAX_QUEUE_SIZE) {
		messageQueue.push(message);
	}
}

// Calculate delay with jitter
function calculateDelay(): number {
	const jitter = Math.random() * currentDelayMs;
	const delay = currentDelayMs + jitter;
	return Math.min(delay, MAX_DELAY_MS);
}

// Exponential backoff with jitter
function scheduleReconnect() {
	if (reconnectTimeout) {
		clearTimeout(reconnectTimeout);
	}

	const delay = calculateDelay();
	console.log(`[WebSocket] Reconnecting in ${Math.round(delay)}ms (current delay: ${currentDelayMs}ms)`);

	reconnectTimeout = setTimeout(() => {
		reconnectTimeout = null;
		connectWebSocket();
	}, delay);
}

// Reconnection logic with exponential backoff
function connectWebSocket() {
	if (sharedConnection) {
		// Connection already exists, don't create another
		return;
	}

	sharedState = 'connecting';

	const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
	const wsUrl = `${protocol}//${window.location.host}/api/ws`;

	sharedConnection = new WebSocket(wsUrl);

	sharedConnection.onopen = () => {
		sharedState = 'connected';
		currentDelayMs = INITIAL_DELAY_MS; // Reset delay on successful connection
		console.log('[WebSocket] Connected');

		// Flush any queued messages
		flushMessageQueue();
	};

	sharedConnection.onmessage = (event) => {
		try {
			const data: WebSocketMessage = JSON.parse(event.data);

			// Dispatch to all registered listeners
			listeners.forEach(listener => listener(data));
		} catch (e) {
			console.error('[WebSocket] Failed to parse message:', e);
		}
	};

	sharedConnection.onerror = (error) => {
		console.error('[WebSocket] Error:', error);
		// Error will trigger onclose, so we don't need to set state here
	};

	sharedConnection.onclose = () => {
		const wasConnected = sharedState === 'connected';
		sharedConnection = null;
		sharedState = 'disconnected';
		console.log('[WebSocket] Disconnected');

		if (!intentionalClose) {
			// Increase delay for next attempt (exponential backoff)
			currentDelayMs = Math.min(currentDelayMs * DELAY_MULTIPLIER, MAX_DELAY_MS);
			scheduleReconnect();
		}
		intentionalClose = false;
	};
}

// Public API for the shared WebSocket connection
export function getWebSocketConnection() {
	return {
		get state() {
			return sharedState;
		},

		connect() {
			if (sharedState === 'disconnected') {
				connectWebSocket();
			}
		},

		disconnect() {
			intentionalClose = true;
			if (reconnectTimeout) {
				clearTimeout(reconnectTimeout);
				reconnectTimeout = null;
			}
			if (sharedConnection) {
				sharedConnection.close();
				sharedConnection = null;
			}
			sharedState = 'disconnected';
			// Reset delay on intentional disconnect
			currentDelayMs = INITIAL_DELAY_MS;
		},

		forceReconnect() {
			this.disconnect();
			currentDelayMs = INITIAL_DELAY_MS;
			this.connect();
		},

		addEventListener(listener: (message: WebSocketMessage) => void) {
			listeners.add(listener);
		},

		removeEventListener(listener: (message: WebSocketMessage) => void) {
			listeners.delete(listener);
		},

		// For debugging purposes
		getConnection() {
			return sharedConnection;
		},

		// Get current backoff state (for debugging)
		getBackoffDelay() {
			return currentDelayMs;
		},

		// Get queue size (for debugging)
		getQueueSize() {
			return messageQueue.length;
		}
	};
}

// Initialize the shared connection when the module is loaded
// This ensures there's only one connection instance
const websocketConnection = getWebSocketConnection();

// Export the singleton instance
export { websocketConnection };
