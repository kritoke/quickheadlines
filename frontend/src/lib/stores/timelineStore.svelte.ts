import { fetchTimeline, fetchConfig } from '$lib/api';
import { deepClone } from '$lib/utils/clone';
import { isIdle, isLoading, isRefreshing, isError, getError } from '$lib/utils/storeTypes';
import type { LoadStatus } from '$lib/utils/storeTypes';
import type { TimelineItemResponse } from '$lib/types';
import { SvelteSet } from 'svelte/reactivity';

export type { LoadStatus };

type BaseTimelineState = {
	items: TimelineItemResponse[];
	itemIds: Set<string>;
	hasMore: boolean;
	offset: number;
	cursor?: string;
	loadingMore: boolean;
	isClustering: boolean;
	refreshMinutes: number;
	// Tab name for timeline (all = global, specific tab = tab-specific)
	tabName: string;
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
	tabName: 'all'
};

const initialState: TimelineStateIdle = {
	...initialBaseState,
	status: 'idle'
};

export const timelineState = $state<TimelineState>({
	...initialState,
	itemIds: new SvelteSet<string>()
});

const clone = deepClone;

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
	isAppend: boolean,
	cursor?: string
): TimelineStateIdle {
	if (isAppend) {
		const newItems = items.filter(item => !state.itemIds.has(item.id));
		const newItemIds = new SvelteSet([...state.itemIds, ...newItems.map(i => i.id)]);
		
		return {
			...state,
			items: [...state.items, ...newItems],
			itemIds: newItemIds,
			hasMore,
			offset: state.offset + newItems.length,
			cursor: cursor,
			loadingMore: false,
			status: 'idle'
		};
	}
	
	return {
		...state,
		items,
		itemIds: new SvelteSet(items.map(i => i.id)),
		hasMore,
		offset: items.length,
		cursor: cursor,
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

export function resetTimelineStore(): void {
	Object.assign(timelineState, {
		...clone(initialBaseState),
		itemIds: new SvelteSet<string>(),
		cursor: undefined
	});
}

export async function loadTimeline(append: boolean = false, tabName: string = 'all'): Promise<void> {
	if (!append && (isRefreshing(timelineState) || isLoading(timelineState))) return;
	
	// Mutate the state instead of reassigning
	Object.assign(timelineState, setLoading(timelineState, append));
	
	try {
		const cursor = append ? timelineState.cursor : undefined;
		const response = await fetchTimeline(100, append ? timelineState.offset : 0, 14, cursor, tabName);
		Object.assign(timelineState, setTimelineData(timelineState, response.items, response.has_more, append, response.cursor));
		// Update tab in state
		timelineState.tabName = tabName;
	} catch (e) {
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
	
	const q = query.toLowerCase();
	return timelineState.items.filter(item => 
		item.title.toLowerCase().includes(q) ||
		item.feed_title.toLowerCase().includes(q)
	);
}

export async function handleLoadMore(): Promise<void> {
	if (!timelineState.loadingMore && timelineState.hasMore) {
		await loadTimeline(true);
	}
}
