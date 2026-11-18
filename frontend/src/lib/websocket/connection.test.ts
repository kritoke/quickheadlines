import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

class FailingSocket {
	static instances = 0;
	onopen: (() => void) | null = null;
	onclose: (() => void) | null = null;
	onerror: ((e: unknown) => void) | null = null;
	onmessage: ((e: { data: string }) => void) | null = null;
	constructor() {
		FailingSocket.instances++;
		queueMicrotask(() => this.onclose?.());
	}
	close() {}
}

describe('websocketConnection reconnect', () => {
	beforeEach(() => {
		vi.resetModules();
		vi.useFakeTimers();
		FailingSocket.instances = 0;
		vi.stubGlobal('WebSocket', FailingSocket);
	});
	afterEach(() => {
		vi.useRealTimers();
		vi.unstubAllGlobals();
	});

	it('keeps retrying after many consecutive failures (no permanent cap)', async () => {
		const { websocketConnection } = await import('./connection');
		websocketConnection.connect();
		for (let i = 0; i < 25; i++) {
			await Promise.resolve();
			await vi.advanceTimersByTimeAsync(31_000);
		}
		expect(FailingSocket.instances).toBeGreaterThan(20);
		websocketConnection.disconnect();
	});

	it('stops retrying after an intentional disconnect', async () => {
		const { websocketConnection } = await import('./connection');
		websocketConnection.connect();
		await Promise.resolve();
		websocketConnection.disconnect();
		const before = FailingSocket.instances;
		await vi.advanceTimersByTimeAsync(120_000);
		expect(FailingSocket.instances).toBe(before);
	});

	it('retries when the WebSocket constructor throws', async () => {
		let calls = 0;
		vi.stubGlobal('WebSocket', class {
			constructor() {
				calls++;
				throw new Error('blocked');
			}
		});
		const { websocketConnection } = await import('./connection');
		websocketConnection.connect();
		await vi.advanceTimersByTimeAsync(120_000);
		expect(calls).toBeGreaterThan(3);
		websocketConnection.disconnect();
	});
});
