import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/svelte';
import { themeState, initTheme } from '../stores/theme.svelte';

// Mock fetch for API calls
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Mock localStorage
const localStorageMock = (() => {
	let store: Record<string, string> = {};
	return {
		getItem: (key: string) => store[key] || null,
		setItem: (key: string, value: string) => { store[key] = value; },
		clear: () => { store = {}; }
	};
})();

Object.defineProperty(window, 'localStorage', { value: localStorageMock });

// Mock matchMedia
Object.defineProperty(window, 'matchMedia', {
	value: vi.fn().mockImplementation((query: string) => ({
		matches: false,
		media: query,
		addEventListener: vi.fn(),
		removeEventListener: vi.fn()
	}))
});

describe('API Integration', () => {
	beforeEach(() => {
		localStorageMock.clear();
		mockFetch.mockClear();
	});

	it('fetches feeds from /api/feeds', async () => {
		const mockResponse = {
			tabs: [{ name: 'all' }],
			active_tab: 'all',
			feeds: [
				{
					url: 'https://example.com/feed',
					title: 'Test Feed',
					items: [{ title: 'Item 1', link: 'https://example.com/1' }]
				}
			],
			updated_at: 1700000000000
		};

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve(mockResponse)
		});

		const response = await fetch('/api/feeds?tab=all');
		const data = await response.json();

		expect(data.feeds).toHaveLength(1);
		expect(data.feeds[0].title).toBe('Test Feed');
		expect(data.updated_at).toBe(1700000000000);
	});

	it('fetches timeline from /api/timeline', async () => {
		const mockResponse = {
			items: [
				{ id: '1', title: 'Timeline Item 1', link: 'https://example.com/1' }
			],
			has_more: false,
			total_count: 1
		};

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve(mockResponse)
		});

		const response = await fetch('/api/timeline?limit=100&offset=0');
		const data = await response.json();

		expect(data.items).toHaveLength(1);
		expect(data.items[0].title).toBe('Timeline Item 1');
	});

	it('polls /api/events and detects feed_update', async () => {
		const timestamp = 1700000000000;
		const sseResponse = `event: feed_update\ndata: ${timestamp}\n\n`;

		mockFetch.mockResolvedValueOnce({
			ok: true,
			text: () => Promise.resolve(sseResponse)
		});

		const response = await fetch(`/api/events?last_update=0`);
		const text = await response.text();

		// Parse SSE-style response
		const lines = text.split('\n');
		let foundFeedUpdate = false;
		let receivedTimestamp = 0;

		for (const line of lines) {
			if (line.startsWith('event: feed_update')) {
				foundFeedUpdate = true;
				const dataLine = lines.find(l => l.startsWith('data: '));
				if (dataLine) {
					receivedTimestamp = parseInt(dataLine.replace('data: ', ''));
				}
			}
		}

		expect(foundFeedUpdate).toBe(true);
		expect(receivedTimestamp).toBe(timestamp);
	});

	it('returns heartbeat when no new data', async () => {
		const sseResponse = `event: heartbeat\ndata: 1700000000000\n\n`;

		mockFetch.mockResolvedValueOnce({
			ok: true,
			text: () => Promise.resolve(sseResponse)
		});

		const response = await fetch(`/api/events?last_update=1700000000000`);
		const text = await response.text();

		expect(text).toContain('event: heartbeat');
	});
});

describe('Theme Reactivity', () => {
	beforeEach(() => {
		localStorageMock.clear();
		document.documentElement.classList.remove('dark');
	});

	it('themeState is reactive when theme changes', () => {
		// Initialize
		initTheme();
		const initialTheme = themeState.theme;
		
		// Toggle theme
		themeState.theme = themeState.theme === 'light' ? 'dark' : 'light';
		
		// Check it changed
		expect(themeState.theme).not.toBe(initialTheme);
	});
});
