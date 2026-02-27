import { fetchFeeds, fetchMoreFeedItems, fetchConfig } from '$lib/api';
import type { FeedResponse, FeedsPageResponse } from '$lib/types';

export type LoadStatus = 'idle' | 'loading' | 'refreshing' | 'error';

type BaseFeedState = {
	feeds: FeedResponse[];
	tabs: { name: string }[];
	activeTab: string;
	lastUpdated: number | null;
	loadingFeeds: Record<string, boolean>;
	tabCache: Record<string, { feeds: FeedResponse[]; loaded: boolean }>;
	refreshMinutes: number;
};

export type FeedStateIdle = BaseFeedState & { status: 'idle' };
export type FeedStateLoading = BaseFeedState & { status: 'loading' };
export type FeedStateRefreshing = BaseFeedState & { status: 'refreshing' };
export type FeedStateError = BaseFeedState & { status: 'error'; error: string };

export type FeedState = FeedStateIdle | FeedStateLoading | FeedStateRefreshing | FeedStateError;

export function isIdle(state: FeedState): state is FeedStateIdle {
	return state.status === 'idle';
}

export function isLoading(state: FeedState): state is FeedStateLoading {
	return state.status === 'loading';
}

export function isRefreshing(state: FeedState): state is FeedStateRefreshing {
	return state.status === 'refreshing';
}

export function isError(state: FeedState): state is FeedStateError {
	return state.status === 'error';
}

export function getError(state: FeedState): string | null {
	return isError(state) ? state.error : null;
}

const initialBaseState: BaseFeedState = {
	feeds: [],
	tabs: [],
	activeTab: 'all',
	lastUpdated: null,
	loadingFeeds: {},
	tabCache: {},
	refreshMinutes: 10
};

const initialState: FeedStateIdle = {
	...initialBaseState,
	status: 'idle'
};

export const feedState = $state<FeedState>({ ...initialState });

function clone<T>(obj: T): T {
	return JSON.parse(JSON.stringify(obj));
}

export function setLoading(state: FeedState, tab: string): FeedStateLoading | FeedStateRefreshing {
	const base: BaseFeedState = {
		...state,
		loadingFeeds: state.loadingFeeds,
		tabCache: state.tabCache
	};
	
	if (state.tabCache[tab]?.loaded) {
		return { ...base, status: 'refreshing' };
	}
	return { ...base, status: 'loading' };
}

export function setFeedsData(state: FeedState, response: FeedsPageResponse, tab: string): FeedStateIdle {
	const swReleases = response.software_releases || [];
	const feeds = [...swReleases, ...(response.feeds || [])];
	
	return {
		...state,
		feeds,
		tabs: response.tabs || [],
		activeTab: tab,
		status: 'idle',
		lastUpdated: response.updated_at || Date.now(),
		tabCache: {
			...state.tabCache,
			[tab]: { feeds: clone(feeds), loaded: true }
		}
	};
}

export function setError(state: FeedState, error: string): FeedStateError {
	return {
		...state,
		status: 'error',
		error
	};
}

export function setFeedLoading(state: FeedState, feedUrl: string, isLoading: boolean): FeedState {
	return {
		...state,
		loadingFeeds: {
			...state.loadingFeeds,
			[feedUrl]: isLoading
		}
	};
}

export function appendFeedItems(
	state: FeedState, 
	feedUrl: string, 
	newItems: FeedResponse['items'],
	totalCount: number
): FeedState {
	const feedIndex = state.feeds.findIndex(f => f.url === feedUrl);
	if (feedIndex === -1) return state;
	
	const updatedFeeds = state.feeds.map((feed, i) => {
		if (i !== feedIndex) return feed;
		return {
			...feed,
			items: [...feed.items, ...newItems],
			total_item_count: totalCount
		};
	});
	
	return {
		...state,
		feeds: updatedFeeds,
		tabCache: {
			...state.tabCache,
			[state.activeTab]: { feeds: clone(updatedFeeds), loaded: true }
		}
	};
}

export function setRefreshMinutes(state: FeedState, minutes: number): FeedState {
	return {
		...state,
		refreshMinutes: minutes
	};
}

export function resetFeedStore(): void {
	Object.assign(feedState, { ...initialState });
}

export async function loadFeeds(tab: string = feedState.activeTab, force: boolean = false): Promise<void> {
	if (!force && feedState.tabCache[tab]?.loaded) {
		feedState.feeds = feedState.tabCache[tab].feeds;
		feedState.activeTab = tab;
		return;
	}

	feedState = setLoading(feedState, tab);
	
	try {
		const response = await fetchFeeds(tab);
		feedState = setFeedsData(feedState, response, tab);
	} catch (e) {
		feedState = setError(feedState, e instanceof Error ? e.message : 'Failed to load feeds');
	}
}

export async function loadMoreFeedItems(feed: FeedResponse): Promise<void> {
	feedState = setFeedLoading(feedState, feed.url, true);
	
	try {
		const currentOffset = feed.items.length;
		const response = await fetchMoreFeedItems(feed.url, 10, currentOffset);
		feedState = appendFeedItems(feedState, feed.url, response.items, response.total_item_count);
	} catch (e) {
		feedState = setError(feedState, e instanceof Error ? e.message : 'Failed to load more items');
	} finally {
		feedState = setFeedLoading(feedState, feed.url, false);
	}
}

export async function loadFeedConfig(): Promise<number> {
	try {
		const config = await fetchConfig();
		const minutes = config.refresh_minutes || 10;
		feedState = setRefreshMinutes(feedState, minutes);
		return minutes;
	} catch {
		return 10;
	}
}

export function setActiveTab(tab: string): void {
	feedState.activeTab = tab;
	
	if (feedState.tabCache[tab]?.loaded) {
		feedState.feeds = feedState.tabCache[tab].feeds;
	}
}

export function getFilteredFeeds(query: string): FeedResponse[] {
	if (!query.trim()) return feedState.feeds;
	
	const q = query.toLowerCase();
	return feedState.feeds
		.map(feed => ({
			...feed,
			items: feed.items.filter(item => 
				item.title.toLowerCase().includes(q) ||
				feed.title.toLowerCase().includes(q)
			)
		}))
		.filter(feed => feed.items.length > 0);
}
