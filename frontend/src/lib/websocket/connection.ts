import { logger } from "#lib/utils/debug";

export type ConnectionState = "connecting" | "connected" | "disconnected";

export type WebSocketMessage = {
	type: "feed_update" | "heartbeat" | "clustering_status";
	timestamp: number;
	is_clustering?: boolean;
};

const INITIAL_DELAY_MS = 1000;
const MAX_DELAY_MS = 30000;

let socket: WebSocket | null = null;
let state: ConnectionState = "disconnected";
let reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
let currentDelayMs = INITIAL_DELAY_MS;
const listeners = new Set<(message: WebSocketMessage) => void>();

/** `location.protocol` already ends in ":" — don't add another. */
export function buildWebSocketUrl(loc: Pick<Location, "protocol" | "host">): string {
	const protocol = loc.protocol === "https:" ? "wss:" : "ws:";
	return `${protocol}//${loc.host}/api/ws`;
}

/** Exponential backoff with jitter. Always schedules another attempt — never gives up. */
function scheduleReconnect(): void {
	if (reconnectTimeout) clearTimeout(reconnectTimeout);
	const delay = Math.min(currentDelayMs + Math.random() * currentDelayMs, MAX_DELAY_MS);
	currentDelayMs = Math.min(currentDelayMs * 2, MAX_DELAY_MS);
	logger.log(`[WebSocket] Reconnecting in ${Math.round(delay)}ms`);
	reconnectTimeout = setTimeout(() => {
		reconnectTimeout = null;
		open();
	}, delay);
}

function open(): void {
	if (socket) return;
	state = "connecting";

	let ws: WebSocket;
	try {
		ws = new WebSocket(buildWebSocketUrl(window.location));
	} catch (e) {
		logger.error("[WebSocket] Failed to create WebSocket:", e);
		state = "disconnected";
		scheduleReconnect();
		return;
	}
	socket = ws;

	ws.onopen = () => {
		state = "connected";
		currentDelayMs = INITIAL_DELAY_MS;
		logger.log("[WebSocket] Connected");
	};

	ws.onmessage = (event) => {
		let data: WebSocketMessage;
		try {
			data = JSON.parse(event.data);
		} catch (e) {
			logger.error("[WebSocket] Failed to parse message:", e);
			return;
		}
		listeners.forEach((listener) => {
			try {
				listener(data);
			} catch (err) {
				logger.error("[WebSocket] Listener error:", err);
			}
		});
	};

	ws.onerror = (error) => logger.error("[WebSocket] Error:", error);

	ws.onclose = () => {
		// Ignore close events from a socket we already dropped via disconnect().
		if (socket !== ws) return;
		socket = null;
		state = "disconnected";
		logger.log("[WebSocket] Disconnected");
		scheduleReconnect();
	};
}

export const websocketConnection = {
	get state(): ConnectionState {
		return state;
	},

	connect(): void {
		if (!socket && !reconnectTimeout) open();
	},

	disconnect(): void {
		if (reconnectTimeout) {
			clearTimeout(reconnectTimeout);
			reconnectTimeout = null;
		}
		const ws = socket;
		socket = null;
		state = "disconnected";
		currentDelayMs = INITIAL_DELAY_MS;
		ws?.close();
	},

	addEventListener(listener: (message: WebSocketMessage) => void): void {
		listeners.add(listener);
	},

	removeEventListener(listener: (message: WebSocketMessage) => void): void {
		listeners.delete(listener);
	},
};
