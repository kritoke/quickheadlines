import type { ConnectionState } from '$lib/websocket';

export const connectionState = $state<{
	state: ConnectionState;
	visible: boolean;
	latency: number | null;
	reconnectAttempts: number;
}>({
	state: 'disconnected',
	visible: false,
	latency: null,
	reconnectAttempts: 0
});

export function setConnectionState(newState: ConnectionState) {
	connectionState.state = newState;
	connectionState.visible = true;
}

export function hideConnectionStatus() {
	connectionState.visible = false;
}

export function setLatency(latency: number) {
	connectionState.latency = latency;
}

export function incrementReconnectAttempts() {
	connectionState.reconnectAttempts++;
}

export function resetReconnectAttempts() {
	connectionState.reconnectAttempts = 0;
}
