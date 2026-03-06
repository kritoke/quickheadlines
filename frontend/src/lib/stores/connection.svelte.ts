import type { ConnectionState } from '$lib/websocket';

export const connectionState = $state<{
	state: ConnectionState;
	visible: boolean;
}>({
	state: 'disconnected',
	visible: false
});

export function setConnectionState(state: ConnectionState) {
	connectionState.state = state;
	connectionState.visible = true;
}

export function hideConnectionStatus() {
	connectionState.visible = false;
}
