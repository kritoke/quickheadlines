import { fetchTimeline, fetchConfig, RateLimitError } from '$lib/api';
import { deepClone } from '$lib/utils/clone';
import { isIdle, isLoading, isRefreshing, isError, getError } from '$lib/utils/storeTypes';
import type { LoadStatus } from '$lib/utils/storeTypes';
import type { TimelineItemResponse } from '$lib/types';
import { SvelteSet } from 'svelte/reactivity';
import { toastStore } from './toast.svelte';

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

export type TimelineStateIdle = BaseTimelineState & { status: 'idle' };
export type TimelineStateLoading = BaseTimelineState & { status: 'loading' };
export type TimelineStateRefreshing = BaseTimelineState & { status: 'refreshing' };
export type TimelineStateError = BaseTimelineState & { status: 'error'; error: string };

export type TimelineState = TimelineStateIdle | TimelineStateLoading | TimelineStateRefreshing | TimelineStateError;

export { isIdle, isLoading, isRefreshing, isError, getError };

const initialBaseState: BaseTimelineState = {
	items: [],
	itemIds: new SvelteSet<string>(),
	hasMore: false,
	offset: 0,
	loadingMore: false,
	isClustering: false,
	refreshMinutes: 10,
	tabName: 'all',
	retryAfterMs: 0
};

const initialState: TimelineStateIdle = {
	...initialBaseState,
	status: 'idle'
};

export const timelineState = $state<TimelineState>({
	...initialState,
	itemIds: new SvelteSet<string>()
});

export function setLoading(state: TimelineState, isAppend: boolean): TimelineState {
	if (isAppend) {
		return { ...state, loadingMore: true };
	}
	if (isRefreshing(state) || isLoading(state)) {
		return state;
	}
	return { ...state, status: 'loading', loadingMore: false };
}

export function setTimelineData(
	state: TimelineState, 
	items: TimelineItemResponse[], 
	hasMore: boolean,
	isAppend: boolean
): TimelineStateIdle {
	if (isAppend) {
		const newItems = items.filter(item => !state.itemIds.has(item.id));
		const newItemIds = new SvelteSet([...state.itemIds, ...newItems.map(item => item.id)]);
		
		return {
			...state,
			items: [...state.items, ...newItems],
			itemIds: newItemIds,
			hasMore,
			offset: state.offset + newItems.length,
			loadingMore: false,
			status: 'idle'
		};
	}
	
	return {
		...state,
		items,
		itemIds: new SvelteSet(items.map(item => item.id)),
		hasMore,
		offset: items.length,
		loadingMore: false,
		status: 'idle'
	};
}

export function setError(state: TimelineState, error: string): TimelineStateError {
	return {
		...state,
		status: 'error',
		loadingMore: false,
		error
	};
}

export function setClustering(state: TimelineState, isClustering: boolean): TimelineState {
	return {
		...state,
		isClustering
	};
}

export function setRefreshMinutes(state: TimelineState, minutes: number): TimelineState {
	return {
		...state,
		refreshMinutes: minutes
	};
}

export function setTabName(state: TimelineState, tab: string): TimelineState {
	return {
		...state,
		tabName: tab
	};
}

export function resetTimelineStore(): void {
	Object.assign(timelineState, {
		...deepClone(initialBaseState),
		itemIds: new SvelteSet<string>()
	});
}

let timelineRequestId = 0;
let retryTimerId: ReturnType<typeof setTimeout> | null = null;

export function cancelRetry(): void {
	if (retryTimerId) {
		clearTimeout(retryTimerId);
		retryTimerId = null;
	}
}

export async function loadTimeline(append: boolean = false, tab?: string): Promise<void> {
	const requestId = ++timelineRequestId;
	tab ??= timelineState.tabName;
	
	
	
	if (!append) {
		if (isRefreshing(timelineState) || isLoading(timelineState)) return;
		
		const isTabChange = tab !== timelineState.tabName;
		const hasExistingData = timelineState.items.length > 0;
		
		if (isTabChange || !hasExistingData) {
			Object.assign(timelineState, {
				...initialBaseState,
				itemIds: new SvelteSet<string>(),
				tabName: tab,
				status: 'loading' as const
			});
		} else {
			Object.assign(timelineState, {
				status: 'refreshing' as const,
				tabName: tab
			});
		}
	}
	
	try {
		const response = await fetchTimeline(500, append ? timelineState.offset : 0, 30, tab === 'all' ? undefined : tab);
		if (requestId !== timelineRequestId) return;
		cancelRetry();
		Object.assign(timelineState, setTimelineData(timelineState, response.items, response.has_more, append));
	} catch (e) {
		if (requestId !== timelineRequestId) return;

		if (e instanceof RateLimitError) {
			Object.assign(timelineState, {
				...setError(timelineState, 'Rate limited'),
				retryAfterMs: e.retryAfterMs
			});
			cancelRetry();
			retryTimerId = setTimeout(() => {
				retryTimerId = null;
				if (requestId === timelineRequestId) {
					loadTimeline(append, tab);
				}
			}, e.retryAfterMs);
			return;
		}

		toastStore.error('Failed to load timeline', 'Timeline');
		Object.assign(timelineState, setError(timelineState, e instanceof Error ? e.message : 'Failed to load timeline'));
	}
}

export async function loadTimelineConfig(): Promise<number> {
	try {
		const config = await fetchConfig();
		const minutes = config.refresh_minutes || 10;
		Object.assign(timelineState, setRefreshMinutes(timelineState, minutes));
		return minutes;
	} catch {
		return 10;
	}
}

export function getFilteredItems(query: string): TimelineItemResponse[] {
	if (!query.trim()) return [...timelineState.items];
	
	const lowerQuery = query.toLowerCase();
	return timelineState.items.filter(item => 
		item.title.toLowerCase().includes(lowerQuery) ||
		item.feed_title.toLowerCase().includes(lowerQuery)
	);
}

export async function handleLoadMore(): Promise<void> {
	if (!timelineState.loadingMore && timelineState.hasMore) {
		await loadTimeline(true);
	}
}

let searchLoadingAll = false;

export async function loadAllRemainingItems(): Promise<void> {
	if (searchLoadingAll || !timelineState.hasMore) return;
	searchLoadingAll = true;
	try {
		while (timelineState.hasMore) {
			await handleLoadMore();
		}
	} finally {
		searchLoadingAll = false;
	}
}

export function isSearchLoadingAll(): boolean {
	return searchLoadingAll;
}
