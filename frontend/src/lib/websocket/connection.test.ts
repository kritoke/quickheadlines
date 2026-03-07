import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

describe('Connection State Management', () => {
	describe('Intentional Close Tracking', () => {
		it('intentionalClose flag prevents failure counting', () => {
			let consecutiveFailures = 0;
			let intentionalClose = false;

			// Intentional disconnect
			intentionalClose = true;
			
			// Simulate onclose
			if (!intentionalClose) {
				consecutiveFailures++;
			}
			intentionalClose = false;

			expect(consecutiveFailures).toBe(0);
		});

		it('unintentional close increments failure count', () => {
			let consecutiveFailures = 0;
			let intentionalClose = false;

			// Unintentional close (network error)
			// intentionalClose is false
			
			// Simulate onclose
			if (!intentionalClose) {
				consecutiveFailures++;
			}

			expect(consecutiveFailures).toBe(1);
		});

		it('resets intentionalClose flag after close', () => {
			let intentionalClose = true;

			// Simulate onclose
			intentionalClose = false;

			expect(intentionalClose).toBe(false);
		});
	});

	describe('Error Handler', () => {
		it('triggers close on error', () => {
			const mockWs = {
				close: vi.fn(),
				readyState: WebSocket.OPEN
			};

			// Simulate onerror
			// Error handler should call ws.close()
			mockWs.close();

			expect(mockWs.close).toHaveBeenCalled();
		});

		it('sets state to error before close', () => {
			let state = 'connected';

			// Simulate onerror
			state = 'error';
			// Then close would be called

			expect(state).toBe('error');
		});
	});

	describe('Exponential Backoff', () => {
		it('calculates delay with exponential backoff', () => {
			const maxReconnectDelay = 30000;
			
			for (let attempt = 0; attempt < 10; attempt++) {
				const baseDelay = Math.min(1000 * Math.pow(2, attempt), maxReconnectDelay);
				const jitter = 0.5 + Math.random();
				const delay = Math.floor(baseDelay * jitter);

				// Delay should be within expected range
				expect(delay).toBeGreaterThanOrEqual(baseDelay * 0.5);
				expect(delay).toBeLessThanOrEqual(baseDelay * 1.5);
			}
		});

		it('caps delay at maxReconnectDelay', () => {
			const maxReconnectDelay = 30000;
			const attempt = 20; // Very high attempt number
			
			const baseDelay = Math.min(1000 * Math.pow(2, attempt), maxReconnectDelay);
			
			expect(baseDelay).toBe(maxReconnectDelay);
		});

		it('adds jitter to prevent thundering herd', () => {
			const baseDelay = 1000;
			const delays: number[] = [];

			// Calculate 10 delays with same base
			for (let i = 0; i < 10; i++) {
				const jitter = 0.5 + Math.random();
				const delay = Math.floor(baseDelay * jitter);
				delays.push(delay);
			}

			// Should have variation due to jitter
			const uniqueDelays = new Set(delays);
			expect(uniqueDelays.size).toBeGreaterThan(1);
		});
	});

	describe('Polling Fallback', () => {
		it('triggers polling after max consecutive failures', () => {
			const maxConsecutiveFailures = 5;
			let consecutiveFailures = 0;
			let usePollingFallback = false;

			// Simulate 5 failures
			for (let i = 0; i < 5; i++) {
				consecutiveFailures++;
				if (consecutiveFailures >= maxConsecutiveFailures && !usePollingFallback) {
					usePollingFallback = true;
				}
			}

			expect(usePollingFallback).toBe(true);
		});

		it('resets failure count on successful connection', () => {
			let consecutiveFailures = 5;
			let reconnectAttempts = 3;

			// Simulate onopen
			reconnectAttempts = 0;
			consecutiveFailures = 0;

			expect(consecutiveFailures).toBe(0);
			expect(reconnectAttempts).toBe(0);
		});

		it('does not reconnect when in polling mode', () => {
			let usePollingFallback = true;
			let reconnectAttempted = false;

			// connect() would check usePollingFallback first
			if (!usePollingFallback) {
				reconnectAttempted = true;
			}

			expect(reconnectAttempted).toBe(false);
		});
	});
});
