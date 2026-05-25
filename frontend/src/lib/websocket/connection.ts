export type ConnectionState = 'connecting' | 'connected' | 'disconnected';

export type WebSocketMessage = {
	type: 'feed_update' | 'heartbeat' | 'clustering_status';
	timestamp: number;
	is_clustering?: boolean;
};

import { logger } from '$lib/utils/debug';
import { setConnectionState, setLatency, incrementReconnectAttempts, resetReconnectAttempts } from '$lib/stores/connection.svelte';

// Shared WebSocket connection instance
let sharedConnection: WebSocket | null = null;
let sharedState: ConnectionState = 'disconnected';
let reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
let intentionalClose = false;
const reconnectListeners = new Set<() => void>();

// Exponential backoff state
const INITIAL_DELAY_MS = 1000;
const MAX_DELAY_MS = 30000;
const DELAY_MULTIPLIER = 2;
let currentDelayMs = INITIAL_DELAY_MS;

// Rate limiting to prevent connection spam
const MAX_CONNECT_ATTEMPTS_PER_MINUTE = 10;
let connectAttempts = 0;
let connectAttemptsResetTime = 0;

function resetConnectAttemptsIfNeeded(): void {
	const now = Date.now();
	if (now > connectAttemptsResetTime) {
		connectAttempts = 0;
		connectAttemptsResetTime = now + 60000; // Reset every minute
	}
}

// Message queue for offline buffering
interface QueuedMessage {
	message: WebSocketMessage;
	queuedAt: number;
}

const messageQueue: QueuedMessage[] = [];
const MAX_QUEUE_SIZE = 100;
const MAX_QUEUE_AGE_MS = 5 * 60 * 1000; // 5 minutes - messages older than this are stale

// Event listeners for WebSocket messages
const listeners = new Set<(message: WebSocketMessage) => void>();

function flushMessageQueue() {
	const now = Date.now();
	while (messageQueue.length > 0) {
		const queued = messageQueue.shift();
		if (queued) {
			// Skip stale messages
			if (now - queued.queuedAt > MAX_QUEUE_AGE_MS) {
				logger.debug('[WebSocket] Skipping stale queued message');
				continue;
			}
			listeners.forEach(listener => {
				try { listener(queued.message); } catch (err) { logger.error('[WebSocket] Listener error:', err); }
			});
		}
	}
}

function queueMessage(message: WebSocketMessage) {
	const now = Date.now();
	
	// Remove stale messages when adding new ones
	while (messageQueue.length > 0 && now - messageQueue[0].queuedAt > MAX_QUEUE_AGE_MS) {
		messageQueue.shift();
	}
	
	if (messageQueue.length < MAX_QUEUE_SIZE) {
		messageQueue.push({ message, queuedAt: now });
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
	incrementReconnectAttempts();
	logger.log(`[WebSocket] Reconnecting in ${Math.round(delay)}ms (current delay: ${currentDelayMs}ms)`);

	reconnectTimeout = setTimeout(() => {
		reconnectTimeout = null;
		connectWebSocket();
	}, delay);
}

export function onReconnect(callback: () => void): () => void {
	reconnectListeners.add(callback);
	return () => reconnectListeners.delete(callback);
}

// Helper to reset connection state after failure
function resetConnectionState(): void {
	sharedConnection = null;
	sharedState = 'disconnected';
	setConnectionState('disconnected');
}

// Reconnection logic with exponential backoff
function connectWebSocket() {
	// Guard against multiple simultaneous connection attempts
	if (sharedConnection || sharedState === 'connecting') {
		return;
	}
	
	// Rate limit connection attempts
	resetConnectAttemptsIfNeeded();
	if (connectAttempts >= MAX_CONNECT_ATTEMPTS_PER_MINUTE) {
		logger.warn('[WebSocket] Rate limited: too many connection attempts');
		return;
	}
	connectAttempts++;

	sharedState = 'connecting';
	setConnectionState('connecting');

	const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
	const wsUrl = `${protocol}://${window.location.host}/api/ws`;

	try {
		sharedConnection = new WebSocket(wsUrl);
	} catch (e) {
		logger.error('[WebSocket] Failed to create WebSocket:', e);
		resetConnectionState();
		return;
	}

	sharedConnection.onopen = () => {
		const wasReconnect = currentDelayMs > INITIAL_DELAY_MS;
		sharedState = 'connected';
		setConnectionState('connected');
		resetReconnectAttempts();
		currentDelayMs = INITIAL_DELAY_MS; // Reset delay on successful connection
		logger.log('[WebSocket] Connected');

		if (wasReconnect) {
			logger.log('[WebSocket] Reconnected, calling hooks');
			reconnectListeners.forEach(listener => listener());
		}

		// Flush any queued messages
		flushMessageQueue();
	};

	sharedConnection.onmessage = (event) => {
		try {
			const data: WebSocketMessage = JSON.parse(event.data);

			// Track latency from heartbeats
			if (data.type === 'heartbeat') {
				const latency = Date.now() - data.timestamp;
				setLatency(latency);
			}

			// Dispatch to all registered listeners
			listeners.forEach(listener => {
				try { listener(data); } catch (err) { logger.error('[WebSocket] Listener error:', err); }
			});
		} catch (e) {
			logger.error('[WebSocket] Failed to parse message:', e);
		}
	};

	sharedConnection.onerror = (error) => {
		logger.error('[WebSocket] Error:', error);
		// Error will trigger onclose, so we don't need to set state here
	};

	sharedConnection.onclose = () => {
		const wasConnected = sharedState === 'connected';
		sharedConnection = null;
		sharedState = 'disconnected';
		setConnectionState('disconnected');
		logger.log('[WebSocket] Disconnected');

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
			// Connect if disconnected or if connection attempt failed and we're stuck in 'connecting'
			if (sharedState === 'disconnected' || sharedState === 'connecting') {
				// If stuck in 'connecting', reset state first
				if (sharedState === 'connecting' && !sharedConnection) {
					resetConnectionState();
				}
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
