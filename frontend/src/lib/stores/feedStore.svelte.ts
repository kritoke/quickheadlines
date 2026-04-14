import { fetchFeeds, fetchMoreFeedItems, fetchConfig } from '$lib/api';
import { deepClone } from '$lib/utils/clone';
import { isIdle, isLoading, isRefreshing, isError, getError } from '$lib/utils/storeTypes';
import type { LoadStatus } from '$lib/utils/storeTypes';
import type { FeedResponse, FeedsPageResponse } from '$lib/types';
import { toastStore } from './toast.svelte';

export type { LoadStatus };

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

export { isIdle, isLoading, isRefreshing, isError, getError };

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

const clone = deepClone;

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
			[state.activeTab]: { feeds: deepClone(updatedFeeds), loaded: true }
		}
	};
}

export function setRefreshMinutes(state: FeedState, minutes: number): FeedState {
	return {
		...state,
		refreshMinutes: minutes
	};
}

export function setActiveTab(state: FeedState, tab: string): FeedState {
	return {
		...state,
		activeTab: tab
	};
}

export function resetFeedStore(): void {
	Object.assign(feedState, { ...initialState });
}

export async function loadFeeds(tab: string, force: boolean = false): Promise<void> {
	Object.assign(feedState, setActiveTab(feedState, tab));
	
	if (!force && feedState.tabCache[tab]?.loaded) {
		feedState.feeds = feedState.tabCache[tab].feeds;
		return;
	}

	Object.assign(feedState, setLoading(feedState, tab));
	
	try {
		const response = await fetchFeeds(tab);
		Object.assign(feedState, setFeedsData(feedState, response, tab));
	} catch (e) {
		Object.assign(feedState, setError(feedState, e instanceof Error ? e.message : 'Failed to load feeds'));
	}
}

export async function loadMoreFeedItems(feed: FeedResponse): Promise<void> {
	const feedUrl = feed.url;
	const currentOffset = feed.items.length;
	
	Object.assign(feedState, setFeedLoading(feedState, feedUrl, true));
	
	try {
		const response = await fetchMoreFeedItems(feedUrl, 10, currentOffset);
		
		const feedInState = feedState.feeds.find(f => f.url === feedUrl);
		
		const updatedFeeds = feedState.feeds.map(f => {
			if (f.url === feedUrl) {
				return {
					...f,
					items: [...f.items, ...response.items],
					total_item_count: response.total_item_count ?? f.total_item_count
				};
			}
			return f;
		});
		
		Object.assign(feedState, { feeds: updatedFeeds });
	} catch (e) {
		toastStore.error(`Failed to load more items from ${feed.title}`, 'Feeds');
		Object.assign(feedState, setError(feedState, e instanceof Error ? e.message : 'Failed to load more items'));
	} finally {
		Object.assign(feedState, setFeedLoading(feedState, feedUrl, false));
	}
}

export async function loadFeedConfig(): Promise<number> {
	try {
		const config = await fetchConfig();
		const minutes = config.refresh_minutes || 10;
		Object.assign(feedState, setRefreshMinutes(feedState, minutes));
		return minutes;
	} catch {
		return 10;
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
