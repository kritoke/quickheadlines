import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

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

Object.defineProperty(window, 'matchMedia', {
	value: vi.fn().mockImplementation((query: string) => ({
		matches: false,
		media: query,
		addEventListener: vi.fn(),
		removeEventListener: vi.fn()
	}))
});

// Need to import after mocks are set up
import { fetchFeeds } from '../api';

describe('fetchFeeds dedup and force bypass', () => {
	beforeEach(() => {
		mockFetch.mockClear();
		localStorageMock.clear();
	});

	it('should deduplicate concurrent requests for the same tab', async () => {
		const mockResponse = {
			tabs: [{ name: 'all' }],
			active_tab: 'all',
			feeds: [{ url: 'https://example.com/feed', title: 'Test', items: [] }],
			updated_at: 1000
		};

		// Create a promise we can control
		let resolveFirst: (value: unknown) => void;
		const firstPromise = new Promise(r => { resolveFirst = r; });

		mockFetch.mockReturnValueOnce({
			ok: true,
			json: () => firstPromise
		});

		// Start two concurrent fetches
		const p1 = fetchFeeds('all');
		const p2 = fetchFeeds('all');

		// Only one fetch call should have been made
		expect(mockFetch).toHaveBeenCalledTimes(1);

		// Resolve the fetch
		resolveFirst!(mockResponse);

		const r1 = await p1;
		const r2 = await p2;

		// Both should get the same result
		expect(r1).toEqual(r2);
	});

	it('should bypass dedup cache when force=true', async () => {
		const staleResponse = {
			tabs: [{ name: 'all' }],
			active_tab: 'all',
			feeds: [{ url: 'https://example.com/feed', title: 'Stale', items: [] }],
			updated_at: 1000
		};

		const freshResponse = {
			tabs: [{ name: 'all' }],
			active_tab: 'all',
			feeds: [{ url: 'https://example.com/feed', title: 'Fresh', items: [{ title: 'New Item' }] }],
			updated_at: 2000
		};

		// First call returns stale data
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve(staleResponse)
		});

		const result1 = await fetchFeeds('all');
		expect(result1.feeds[0].title).toBe('Stale');

		// Second call without force — should be deduped (but promise already resolved, so no cache hit)
		// This is expected: once the promise resolves, it's removed from pendingRequests

		// Third call with force=true should bypass any caching
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve(freshResponse)
		});

		const result2 = await fetchFeeds('all', { force: true });
		expect(mockFetch).toHaveBeenCalledTimes(2);
		expect(result2.feeds[0].title).toBe('Fresh');
	});

	it('should add cache-buster param when force=true', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve({ tabs: [], feeds: [], updated_at: 1 })
		});

		await fetchFeeds('all', { force: true });

		const calledUrl = mockFetch.mock.calls[0][0] as string;
		expect(calledUrl).toContain('_t=');
		expect(calledUrl).toContain('tab=all');
	});

	it('should NOT add cache-buster param when force is false/undefined', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve({ tabs: [], feeds: [], updated_at: 1 })
		});

		await fetchFeeds('all');

		const calledUrl = mockFetch.mock.calls[0][0] as string;
		expect(calledUrl).not.toContain('_t=');
	});

	it('should force fresh fetch even when pending request exists', async () => {
		const staleResponse = {
			tabs: [{ name: 'all' }],
			active_tab: 'all',
			feeds: [{ url: 'https://example.com/feed', title: 'Stale', items: [] }],
			updated_at: 1000
		};

		const freshResponse = {
			tabs: [{ name: 'all' }],
			active_tab: 'all',
			feeds: [{ url: 'https://example.com/feed', title: 'Fresh', items: [{ title: 'New' }] }],
			updated_at: 2000
		};

		// Create a slow-pending request
		let resolvePending: (value: unknown) => void;
		const pendingPromise = new Promise(r => { resolvePending = r; });

		mockFetch.mockReturnValueOnce({
			ok: true,
			json: () => pendingPromise
		});

		// Start normal request (goes into dedup cache)
		const p1 = fetchFeeds('all');

		// Force request should bypass the pending dedup
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: () => Promise.resolve(freshResponse)
		});

		const forceResult = await fetchFeeds('all', { force: true });
		expect(forceResult.feeds[0].title).toBe('Fresh');

		// Two separate fetch calls should have been made
		expect(mockFetch).toHaveBeenCalledTimes(2);

		// Resolve the pending request
		resolvePending!(staleResponse);
		await p1;
	});
});
