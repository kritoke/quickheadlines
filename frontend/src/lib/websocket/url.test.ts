import { describe, it, expect } from 'vitest';
import { buildWebSocketUrl } from './connection';

describe('buildWebSocketUrl', () => {
	it('builds ws:// for http pages', () => {
		expect(buildWebSocketUrl({ protocol: 'http:', host: 'localhost:8080' })).toBe('ws://localhost:8080/api/ws');
	});
	it('builds wss:// for https pages', () => {
		expect(buildWebSocketUrl({ protocol: 'https:', host: 'news.example.com' })).toBe('wss://news.example.com/api/ws');
	});
	it('produces a URL the WebSocket constructor accepts', () => {
		expect(() => new URL(buildWebSocketUrl({ protocol: 'http:', host: 'h:1' }))).not.toThrow();
		expect(new URL(buildWebSocketUrl({ protocol: 'http:', host: 'h:1' })).protocol).toBe('ws:');
	});
});
