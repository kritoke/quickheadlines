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

// Event listeners for WebSocket messages
const listeners = new Set<(message: WebSocketMessage) => void>();

// Reconnection logic with fixed 3-second delay
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
		console.log('[WebSocket] Connected');
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
		sharedConnection = null;
		sharedState = 'disconnected';
		console.log('[WebSocket] Disconnected');

		if (!intentionalClose) {
			// Attempt reconnection after 3 seconds
			if (reconnectTimeout) {
				clearTimeout(reconnectTimeout);
			}
			reconnectTimeout = setTimeout(() => {
				reconnectTimeout = null;
				connectWebSocket();
			}, 3000);
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
		},
		
		forceReconnect() {
			this.disconnect();
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
		}
	};
}

// Initialize the shared connection when the module is loaded
// This ensures there's only one connection instance
const websocketConnection = getWebSocketConnection();

// Export the singleton instance
export { websocketConnection };