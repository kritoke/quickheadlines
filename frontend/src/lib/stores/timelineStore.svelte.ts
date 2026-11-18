import { fetchTimeline, RateLimitError } from "#lib/api";
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
import type { TimelineItemResponse } from "#lib/types";
import { SvelteSet } from "svelte/reactivity";
import { saveTab } from "./tabStore.svelte";

export type { LoadStatus };

type BaseTimelineState = {
	items: TimelineItemResponse[];
	itemIds: Set<string>;
	hasMore: boolean;
	offset: number;
	loadingMore: boolean;
	isClustering: boolean;
	refreshMinutes: number;
	tabName: string;
	retryAfterMs: number;
};

export type TimelineStateIdle = BaseTimelineState & { status: "idle" };
export type TimelineStateLoading = BaseTimelineState & { status: "loading" };
export type TimelineStateRefreshing = BaseTimelineState & {
	status: "refreshing";
};
export type TimelineStateError = BaseTimelineState & {
	status: "error";
	error: string;
};

export type TimelineState =
	| TimelineStateIdle
	| TimelineStateLoading
	| TimelineStateRefreshing
	| TimelineStateError;

export { isIdle, isLoading, isRefreshing, isError, getError };

const initialBaseState: BaseTimelineState = {
	items: [],
	itemIds: new SvelteSet<string>(),
	hasMore: false,
	offset: 0,
	loadingMore: false,
	isClustering: false,
	refreshMinutes: 10,
	tabName: "all",
	retryAfterMs: 0,
};

const initialState: TimelineStateIdle = {
	...initialBaseState,
	status: "idle",
};

export const timelineState = $state<TimelineState>({
	...initialState,
	itemIds: new SvelteSet<string>(),
});

export function setTimelineData(
	state: TimelineState,
	items: TimelineItemResponse[],
	hasMore: boolean,
	isAppend: boolean,
): TimelineStateIdle {
	if (isAppend) {
		const newItems = items.filter((item) => !state.itemIds.has(item.id));
		const newItemIds = new SvelteSet([
			...state.itemIds,
			...newItems.map((item) => item.id),
		]);

		return {
			...state,
			items: [...state.items, ...newItems],
			itemIds: newItemIds,
			hasMore,
			offset: state.offset + newItems.length,
			loadingMore: false,
			status: "idle",
		};
	}

	return {
		...state,
		items,
		itemIds: new SvelteSet(items.map((item) => item.id)),
		hasMore,
		offset: items.length,
		loadingMore: false,
		status: "idle",
	};
}

export function setError(
	state: TimelineState,
	error: string,
): TimelineStateError {
	return {
		...state,
		status: "error",
		loadingMore: false,
		error,
	};
}

export function setRefreshMinutes(
	state: TimelineState,
	minutes: number,
): TimelineState {
	return {
		...state,
		refreshMinutes: minutes,
	};
}

export function setTabName(state: TimelineState, tab: string): TimelineState {
	saveTab(tab);
	return {
		...state,
		tabName: tab,
	};
}

export function resetTimelineStore(): void {
	cancelRetry();
	Object.assign(timelineState, {
		...deepClone(initialBaseState),
		itemIds: new SvelteSet<string>(),
	});
}

// Incremented by every full load (refresh / tab change). Any request or retry
// started under an older generation is stale and discarded, so old offsets
// never mix into new data.
let timelineGeneration = 0;
let retryTimerId: ReturnType<typeof setTimeout> | null = null;

export function cancelRetry(): void {
	if (retryTimerId) {
		clearTimeout(retryTimerId);
		retryTimerId = null;
	}
}

export async function loadTimeline(
	append: boolean = false,
	tab?: string,
): Promise<void> {
	tab ??= timelineState.tabName;

	if (append) {
		// Appends only extend the current list: skip if a full load is in flight
		// (it will replace the items and offset) or another append is running.
		if (
			timelineState.loadingMore ||
			isRefreshing(timelineState) ||
			isLoading(timelineState)
		)
			return;
		timelineState.loadingMore = true;
	} else {
		const isTabChange = tab !== timelineState.tabName;
		// A tab change supersedes an in-flight load; a plain refresh does not.
		if (
			!isTabChange &&
			(isRefreshing(timelineState) || isLoading(timelineState))
		)
			return;

		// Bump the generation: any in-flight request from an older generation
		// (refresh or append) is now stale and will be discarded.
		timelineGeneration++;
		const hasExistingData = timelineState.items.length > 0;

		if (isTabChange || !hasExistingData) {
			Object.assign(timelineState, {
				...initialBaseState,
				itemIds: new SvelteSet<string>(),
				tabName: tab,
				status: "loading" as const,
			});
		} else {
			Object.assign(timelineState, {
				status: "refreshing" as const,
				loadingMore: false,
				tabName: tab,
			});
		}
	}

	const generation = timelineGeneration;
	const isStale = () => generation !== timelineGeneration;

	try {
		const response = await fetchTimeline(
			500,
			append ? timelineState.offset : 0,
			30,
			tab === "all" ? undefined : tab,
		);
		if (isStale()) return;
		cancelRetry();
		Object.assign(
			timelineState,
			setTimelineData(timelineState, response.items, response.has_more, append),
		);
	} catch (e) {
		if (isStale()) return;

		if (e instanceof RateLimitError) {
			Object.assign(timelineState, {
				...setError(timelineState, "Rate limited"),
				retryAfterMs: e.retryAfterMs,
			});
			cancelRetry();
			retryTimerId = setTimeout(() => {
				retryTimerId = null;
				// Only retry if nothing newer has replaced this timeline since.
				if (generation === timelineGeneration) loadTimeline(append, tab);
			}, e.retryAfterMs);
			return;
		}

		Object.assign(
			timelineState,
			setError(
				timelineState,
				e instanceof Error ? e.message : "Failed to load timeline",
			),
		);
	}
}

export async function loadTimelineConfig(): Promise<number> {
	return loadConfigForStore(timelineState, setRefreshMinutes);
}

export function getFilteredItems(query: string): TimelineItemResponse[] {
	if (!query.trim()) return [...timelineState.items];

	const lowerQuery = query.toLowerCase();
	return timelineState.items.filter(
		(item) =>
			item.title.toLowerCase().includes(lowerQuery) ||
			item.feed_title.toLowerCase().includes(lowerQuery),
	);
}

/** Returns true if a page was requested, false if skipped. */
export async function handleLoadMore(): Promise<boolean> {
	if (
		timelineState.loadingMore ||
		!timelineState.hasMore ||
		isLoading(timelineState) ||
		isRefreshing(timelineState)
	) {
		return false;
	}
	await loadTimeline(true);
	return true;
}

let searchLoadingAll = false;

export async function loadAllRemainingItems(): Promise<void> {
	if (searchLoadingAll || !timelineState.hasMore) return;
	searchLoadingAll = true;
	try {
		// Stop if a page couldn't be requested (another load in flight) or the
		// last one failed — otherwise this would spin forever.
		while (timelineState.hasMore && !isError(timelineState)) {
			if (!(await handleLoadMore())) break;
		}
	} finally {
		searchLoadingAll = false;
	}
}

export function isSearchLoadingAll(): boolean {
	return searchLoadingAll;
}
