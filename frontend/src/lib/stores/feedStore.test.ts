import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('#lib/api', () => ({
	fetchFeeds: vi.fn(),
	fetchMoreFeedItems: vi.fn(),
}));
vi.mock('#lib/utils/storeConfig', () => ({ loadConfigForStore: vi.fn() }));
vi.mock('./tabStore.svelte', () => ({ saveTab: vi.fn() }));

import { fetchFeeds, fetchMoreFeedItems } from '#lib/api';
import {
	feedState,
	loadFeeds,
	loadMoreFeedItems,
	resetFeedStore,
	getCachedFeeds,
	getLoadedTab,
} from './feedStore.svelte';

const feed = (url: string, n: number) => ({
	url,
	title: url,
	items: Array.from({ length: n }, (_, i) => ({ title: `${url}-${i}`, link: `${url}/${i}` })),
	total_item_count: 50,
});

const response = (feeds: unknown[], tabs = [{ name: 'Tech' }, { name: 'News' }]) => ({
	feeds,
	tabs,
	software_releases: [],
	updated_at: 1,
});

describe('feedStore tab cache', () => {
	beforeEach(() => {
		resetFeedStore();
		vi.mocked(fetchFeeds).mockReset();
		vi.mocked(fetchMoreFeedItems).mockReset();
	});

	it('tracks the most recently requested tab, even if it fails', async () => {
		expect(getLoadedTab()).toBe('all');
		vi.mocked(fetchFeeds).mockRejectedValueOnce(new Error('down'));
		await loadFeeds('Tech');
		expect(getLoadedTab()).toBe('Tech');
		expect('activeTab' in feedState).toBe(false);
	});

	it('shows cached feeds immediately when switching back to a tab', async () => {
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([feed('a', 2)]) as never);
		await loadFeeds('tech');
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([feed('b', 2)]) as never);
		await loadFeeds('news');

		let resolve!: (v: unknown) => void;
		vi.mocked(fetchFeeds).mockReturnValueOnce(new Promise((r) => (resolve = r)) as never);
		const pending = loadFeeds('tech');
		// Before the network responds, the cached tab is already displayed.
		expect(feedState.feeds.map((f) => f.url)).toEqual(['a']);
		expect(feedState.status).toBe('refreshing');
		resolve(response([feed('a2', 1)]));
		await pending;
		expect(feedState.feeds.map((f) => f.url)).toEqual(['a2']);
	});

	it('does not use the cache on forced loads', async () => {
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([feed('a', 2)]) as never);
		await loadFeeds('tech');
		feedState.feeds = [];
		vi.mocked(fetchFeeds).mockReturnValueOnce(new Promise(() => {}) as never);
		void loadFeeds('tech', true);
		expect(feedState.feeds).toEqual([]);
	});

	it('does not cache empty responses', async () => {
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([]) as never);
		await loadFeeds('tech');
		expect(getCachedFeeds('tech')).toBeUndefined();
	});

	it('drops cached tabs the server no longer reports', async () => {
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([feed('a', 1)]) as never);
		await loadFeeds('tech');
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([feed('b', 1)], [{ name: 'News' }]) as never);
		await loadFeeds('news');
		expect(getCachedFeeds('tech')).toBeUndefined();
		expect(getCachedFeeds('news')).toBeDefined();
	});

	it('load-more does not mutate the cached feeds', async () => {
		vi.mocked(fetchFeeds).mockResolvedValueOnce(response([feed('a', 2)]) as never);
		await loadFeeds('tech');
		const cached = getCachedFeeds('tech')!;
		vi.mocked(fetchMoreFeedItems).mockResolvedValueOnce({
			items: [{ title: 'new', link: 'a/new' }],
			total_item_count: 50,
		} as never);
		await loadMoreFeedItems(feedState.feeds[0]);
		expect(feedState.feeds[0].items).toHaveLength(3);
		expect(cached[0].items).toHaveLength(2);
	});
});
