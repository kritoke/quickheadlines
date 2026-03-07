export type ConnectionState = 'connecting' | 'connected' | 'disconnected' | 'error' | 'polling';

export type WebSocketMessage = {
	type: 'feed_update' | 'heartbeat';
	timestamp: number;
};

type BroadcastMessage = {
	type: 'leader_heartbeat' | 'leader_update' | 'election' | 'leader_claim';
	tabId: string;
	timestamp?: number;
	data?: WebSocketMessage;
};

/**
 * Multi-tab aware WebSocket connection using BroadcastChannel API.
 * Only one tab (the leader) maintains the actual WebSocket connection.
 * Other tabs receive updates via BroadcastChannel.
 */
export function createLiveConnection(
	onUpdate: (timestamp: number) => void,
	onFallbackToPolling?: () => void,
	onRecoveredFromPolling?: () => void
) {
	let ws: WebSocket | null = null;
	let reconnectAttempts = 0;
	let consecutiveFailures = 0;
	let usePollingFallback = false;
	let intentionalClose = false;
	const maxReconnectDelay = 30000;
	const maxConsecutiveFailures = 5;

	// Multi-tab coordination
	const tabId = `tab-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	let isLeader = false;
	let leaderId: string | null = null;
	let lastLeaderHeartbeat = 0;
	const LEADER_TIMEOUT = 5000; // 5 seconds
	let heartbeatInterval: ReturnType<typeof setInterval> | null = null;
	let leaderCheckInterval: ReturnType<typeof setInterval> | null = null;
	
	// BroadcastChannel for cross-tab communication
	let channel: BroadcastChannel | null = null;
	
	const state = $state<ConnectionState>('disconnected');

	/**
	 * Initialize BroadcastChannel for multi-tab coordination
	 */
	function initBroadcastChannel() {
		if (typeof BroadcastChannel === 'undefined') {
			// Browser doesn't support BroadcastChannel, fall back to single-tab mode
			console.warn('[WebSocket] BroadcastChannel not supported, using single-tab mode');
			return false;
		}

		try {
			channel = new BroadcastChannel('quickheadlines-websocket');
			
			channel.onmessage = (event: MessageEvent<BroadcastMessage>) => {
				const msg = event.data;
				
				switch (msg.type) {
					case 'leader_heartbeat':
						// Leader is alive
						if (msg.tabId !== tabId) {
							leaderId = msg.tabId;
							lastLeaderHeartbeat = Date.now();
						}
						break;
						
					case 'leader_update':
						// Received update from leader
						if (msg.tabId !== tabId && msg.data) {
							if (msg.data.type === 'feed_update') {
								console.log('[WebSocket] Received update from leader tab:', msg.data.timestamp);
								onUpdate(msg.data.timestamp);
							}
						}
						break;
						
					case 'election':
						// Leader election - tab with lowest ID wins
						if (msg.tabId < tabId) {
							// Other tab has priority
							isLeader = false;
							leaderId = msg.tabId;
						} else if (!leaderId || msg.tabId < leaderId) {
							leaderId = msg.tabId;
						}
						break;
						
					case 'leader_claim':
						// Another tab claimed leadership
						if (msg.tabId !== tabId) {
							isLeader = false;
							leaderId = msg.tabId;
							lastLeaderHeartbeat = Date.now();
							
							// If we were connected, disconnect
							if (ws) {
								intentionalClose = true;
								ws.close();
								ws = null;
							}
						}
						break;
				}
			};
			
			return true;
		} catch (e) {
			console.warn('[WebSocket] Failed to create BroadcastChannel:', e);
			return false;
		}
	}

	/**
	 * Start leader election process
	 */
	function startElection() {
		if (!channel) return;
		
		// Broadcast election message
		channel.postMessage({
			type: 'election',
			tabId: tabId
		} as BroadcastMessage);
		
		// Wait a bit for responses, then claim leadership if no higher priority tab
		setTimeout(() => {
			if (!leaderId || tabId < leaderId) {
				claimLeadership();
			}
		}, 100);
	}

	/**
	 * Claim leadership and start WebSocket connection
	 */
	function claimLeadership() {
		isLeader = true;
		leaderId = tabId;
		
		console.log('[WebSocket] Claimed leadership for tab:', tabId);
		
		if (channel) {
			channel.postMessage({
				type: 'leader_claim',
				tabId: tabId
			} as BroadcastMessage);
		}
		
		// Start actual WebSocket connection
		connectWebSocket();
		
		// Start sending heartbeats to other tabs
		startLeaderHeartbeat();
	}

	/**
	 * Send periodic heartbeats to indicate leader is alive
	 */
	function startLeaderHeartbeat() {
		if (heartbeatInterval) {
			clearInterval(heartbeatInterval);
		}
		
		heartbeatInterval = setInterval(() => {
			if (isLeader && channel) {
				channel.postMessage({
					type: 'leader_heartbeat',
					tabId: tabId
				} as BroadcastMessage);
			}
		}, 2000); // Every 2 seconds
	}

	/**
	 * Check if leader is still alive
	 */
	function startLeaderCheck() {
		if (leaderCheckInterval) {
			clearInterval(leaderCheckInterval);
		}
		
		leaderCheckInterval = setInterval(() => {
			if (leaderId && leaderId !== tabId) {
				const timeSinceLastHeartbeat = Date.now() - lastLeaderHeartbeat;
				
				if (timeSinceLastHeartbeat > LEADER_TIMEOUT) {
					console.log('[WebSocket] Leader timeout, starting election');
					// Leader is dead, start new election
					leaderId = null;
					startElection();
				}
			} else if (!leaderId) {
				// No leader, start election
				startElection();
			}
		}, 1000); // Check every second
	}

	/**
	 * Connect to WebSocket (only called by leader tab)
	 */
	function connectWebSocket() {
		if (usePollingFallback) {
			return;
		}

		state = 'connecting';

		const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
		const wsUrl = `${protocol}//${window.location.host}/api/ws`;

		ws = new WebSocket(wsUrl);

		ws.onopen = () => {
			reconnectAttempts = 0;
			consecutiveFailures = 0;

			if (usePollingFallback) {
				usePollingFallback = false;
				console.log('[WebSocket] Recovered from polling fallback');
				onRecoveredFromPolling?.();
			}

			state = 'connected';
			console.log('[WebSocket] Connected (leader:', tabId, ')');
		};

		ws.onmessage = (event) => {
			try {
				const data: WebSocketMessage = JSON.parse(event.data);

				if (data.type === 'feed_update') {
					console.log('[WebSocket] Feed update received:', data.timestamp);
					onUpdate(data.timestamp);
					
					// Broadcast to other tabs
					if (channel && isLeader) {
						channel.postMessage({
							type: 'leader_update',
							tabId: tabId,
							data: data
						} as BroadcastMessage);
					}
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
			// Force close to trigger onclose and reconnect logic
			if (ws) {
				ws.close();
			}
		};

		ws.onclose = () => {
			state = 'disconnected';
			console.log('[WebSocket] Disconnected');
			ws = null;

			// Only count failures for unintentional closes
			if (!intentionalClose) {
				consecutiveFailures++;
			}

			// Reset flag
			intentionalClose = false;

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
			setTimeout(connectWebSocket, delay);
		};
	}

	/**
	 * Main connect function - handles multi-tab coordination
	 */
	function connect() {
		const hasBroadcastChannel = initBroadcastChannel();
		
		if (!hasBroadcastChannel) {
			// No BroadcastChannel support, connect directly
			connectWebSocket();
			return;
		}
		
		// Start leader check
		startLeaderCheck();
		
		// Start election process
		startElection();
	}

	function disconnect() {
		intentionalClose = true;
		
		// Stop intervals
		if (heartbeatInterval) {
			clearInterval(heartbeatInterval);
			heartbeatInterval = null;
		}
		if (leaderCheckInterval) {
			clearInterval(leaderCheckInterval);
			leaderCheckInterval = null;
		}
		
		// Close WebSocket if we're the leader
		if (ws) {
			ws.close();
			ws = null;
		}
		
		// Close BroadcastChannel
		if (channel) {
			channel.close();
			channel = null;
		}
		
		// Reset state
		isLeader = false;
		leaderId = null;
		usePollingFallback = false;
		consecutiveFailures = 0;
		state = 'disconnected';
	}

	function forceReconnect() {
		consecutiveFailures = 0;
		usePollingFallback = false;
		
		if (isLeader) {
			if (ws) {
				intentionalClose = true;
				ws.close();
			}
			connectWebSocket();
		} else {
			connect();
		}
	}

	return {
		get state() {
			return state;
		},
		get isUsingPolling() {
			return usePollingFallback;
		},
		get isLeader() {
			return isLeader;
		},
		get tabId() {
			return tabId;
		},
		connect,
		disconnect,
		forceReconnect
	};
}
