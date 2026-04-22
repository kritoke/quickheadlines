import type { ConnectionState } from '$lib/websocket';

let hideTimeout: ReturnType<typeof setTimeout> | null = null;

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
	if (hideTimeout) clearTimeout(hideTimeout);
	if (newState === 'connected') {
		hideTimeout = setTimeout(hideConnectionStatus, 2000);
	}
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