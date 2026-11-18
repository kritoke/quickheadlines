import { fetchFeeds, fetchMoreFeedItems } from "#lib/api";
import { loadConfigForStore } from "#lib/utils/storeConfig";
import { deepClone } from "#lib/utils/clone";
import {
	isIdle,
	isLoading,
	isRefreshing,
	isError,
	getError,
} from "#lib/utils/storeTypes";
import type { LoadStatus } from "#lib/utils/storeTypes";
import type { FeedResponse, FeedsPageResponse } from "#lib/types";
import { saveTab } from "./tabStore.svelte";

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

export type FeedStateIdle = BaseFeedState & { status: "idle" };
export type FeedStateLoading = BaseFeedState & { status: "loading" };
export type FeedStateRefreshing = BaseFeedState & { status: "refreshing" };
export type FeedStateError = BaseFeedState & { status: "error"; error: string };

export type FeedState =
	| FeedStateIdle
	| FeedStateLoading
	| FeedStateRefreshing
	| FeedStateError;

export { isIdle, isLoading, isRefreshing, isError, getError };

// Request tracking to prevent race conditions on tab switch
let feedRequestId = 0;

const initialBaseState: BaseFeedState = {
	feeds: [],
	tabs: [],
	activeTab: "all",
	lastUpdated: null,
	loadingFeeds: {},
	tabCache: {},
	refreshMinutes: 10,
};

const initialState: FeedStateIdle = {
	...initialBaseState,
	status: "idle",
};

export const feedState = $state<FeedState>({ ...initialState });

export function setLoading(
	state: FeedState,
	tab: string,
): FeedStateLoading | FeedStateRefreshing {
	return {
		...state,
		status: state.tabCache[tab]?.loaded ? "refreshing" : "loading",
	};
}

export function setFeedsData(
	state: FeedState,
	response: FeedsPageResponse,
	tab: string,
): FeedStateIdle {
	const swReleases = response.software_releases || [];
	const newFeeds = [...swReleases, ...(response.feeds || [])];

	// The single preserve-on-empty rule: an empty response never wipes feeds
	// (or tabs) we are already showing; it is treated as "nothing new yet".
	const feedsToUse = newFeeds.length > 0 ? newFeeds : state.feeds;
	const tabs = response.tabs?.length ? response.tabs : state.tabs;

	// Only mark cache as loaded if we got actual new data from API
	// Don't cache empty results - they should NOT mark cache as loaded
	// so next refresh will try again
	const updatedCache =
		newFeeds.length > 0
			? {
					...state.tabCache,
					[tab]: { feeds: deepClone(newFeeds), loaded: true },
				}
			: state.tabCache;

	return {
		...state,
		feeds: feedsToUse,
		tabs,
		activeTab: tab,
		status: "idle",
		lastUpdated: response.updated_at || Date.now(),
		tabCache: updatedCache,
	};
}

export function setError(state: FeedState, error: string): FeedStateError {
	return {
		...state,
		status: "error",
		error,
	};
}

export function setFeedLoading(
	state: FeedState,
	feedUrl: string,
	isLoading: boolean,
): FeedState {
	return {
		...state,
		loadingFeeds: {
			...state.loadingFeeds,
			[feedUrl]: isLoading,
		},
	};
}

export function setRefreshMinutes(
	state: FeedState,
	minutes: number,
): FeedState {
	return {
		...state,
		refreshMinutes: minutes,
	};
}

export function setActiveTab(state: FeedState, tab: string): FeedState {
	saveTab(tab);
	return {
		...state,
		activeTab: tab,
	};
}

export function resetFeedStore(): void {
	feedRequestId = 0;
	Object.assign(feedState, { ...initialState });
}

export async function loadFeeds(
	tab: string,
	force: boolean = false,
): Promise<void> {
	const requestId = ++feedRequestId;
	const previousTabs = feedState.tabs;

	Object.assign(feedState, setActiveTab(feedState, tab));

	// Show cached feeds for this tab immediately while the fresh copy loads.
	const cached = feedState.tabCache[tab];
	if (!force && cached?.loaded && cached.feeds.length > 0) {
		feedState.feeds = cached.feeds;
	}
	Object.assign(feedState, setLoading(feedState, tab));

	try {
		const response = await fetchFeeds(tab, { force });
		if (requestId !== feedRequestId) return; // superseded by a newer load
		Object.assign(feedState, setFeedsData(feedState, response, tab));
	} catch {
		if (requestId !== feedRequestId) return;
		// Keep whatever feeds are showing; apiFetch has already toasted the error.
		feedState.tabs = previousTabs;
		feedState.status = "idle";
	}
}

export async function loadMoreFeedItems(feed: FeedResponse): Promise<void> {
	const feedUrl = feed.url;
	const currentOffset = feed.items.length;

	Object.assign(feedState, setFeedLoading(feedState, feedUrl, true));

	try {
		const response = await fetchMoreFeedItems(feedUrl, 10, currentOffset);

		const updatedFeeds = feedState.feeds.map((f) => {
			if (f.url === feedUrl) {
				return {
					...f,
					items: [...f.items, ...response.items],
					total_item_count: response.total_item_count ?? f.total_item_count,
				};
			}
			return f;
		});

		Object.assign(feedState, { feeds: updatedFeeds });
	} catch (e) {
		Object.assign(
			feedState,
			setError(
				feedState,
				e instanceof Error ? e.message : "Failed to load more items",
			),
		);
	} finally {
		Object.assign(feedState, setFeedLoading(feedState, feedUrl, false));
	}
}

export async function loadFeedConfig(): Promise<number> {
	return loadConfigForStore(feedState, setRefreshMinutes);
}

export function getFilteredFeeds(query: string): FeedResponse[] {
	if (!query.trim()) return feedState.feeds;

	const lowerQuery = query.toLowerCase();
	return feedState.feeds
		.map((feed) => ({
			...feed,
			items: feed.items.filter(
				(item) =>
					item.title.toLowerCase().includes(lowerQuery) ||
					feed.title.toLowerCase().includes(lowerQuery),
			),
		}))
		.filter((feed) => feed.items.length > 0);
}
