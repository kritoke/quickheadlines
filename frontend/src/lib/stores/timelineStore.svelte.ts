import { fetchTimeline, fetchConfig, fetchStatus } from '$lib/api';
import type { TimelineItemResponse } from '$lib/types';
import { SvelteSet } from 'svelte/reactivity';

export type LoadStatus = 'idle' | 'loading' | 'refreshing' | 'error';

type BaseTimelineState = {
	items: TimelineItemResponse[];
	itemIds: Set<string>;
	hasMore: boolean;
	offset: number;
	loadingMore: boolean;
	isClustering: boolean;
	refreshMinutes: number;
};

export type TimelineStateIdle = BaseTimelineState & { status: 'idle' };
export type TimelineStateLoading = BaseTimelineState & { status: 'loading' };
export type TimelineStateRefreshing = BaseTimelineState & { status: 'refreshing' };
export type TimelineStateError = BaseTimelineState & { status: 'error'; error: string };

export type TimelineState = TimelineStateIdle | TimelineStateLoading | TimelineStateRefreshing | TimelineStateError;

export function isIdle(state: TimelineState): state is TimelineStateIdle {
	return state.status === 'idle';
}

export function isLoading(state: TimelineState): state is TimelineStateLoading {
	return state.status === 'loading';
}

export function isRefreshing(state: TimelineState): state is TimelineStateRefreshing {
	return state.status === 'refreshing';
}

export function isError(state: TimelineState): state is TimelineStateError {
	return state.status === 'error';
}

export function getError(state: TimelineState): string | null {
	return isError(state) ? state.error : null;
}

const initialBaseState: BaseTimelineState = {
	items: [],
	itemIds: new SvelteSet<string>(),
	hasMore: false,
	offset: 0,
	loadingMore: false,
	isClustering: false,
	refreshMinutes: 10
};

const initialState: TimelineStateIdle = {
	...initialBaseState,
	status: 'idle'
};

export const timelineState = $state<TimelineState>({
	...initialState,
	itemIds: new SvelteSet<string>()
});

function clone<T>(obj: T): T {
	return JSON.parse(JSON.stringify(obj));
}

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
		const newItemIds = new SvelteSet([...state.itemIds, ...newItems.map(i => i.id)]);
		
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
		itemIds: new SvelteSet(items.map(i => i.id)),
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

export function resetTimelineStore(): void {
	Object.assign(timelineState, {
		...clone(initialBaseState),
		itemIds: new SvelteSet<string>()
	});
}

export async function loadTimeline(append: boolean = false): Promise<void> {
	if (!append && (isRefreshing(timelineState) || isLoading(timelineState))) return;
	
	timelineState = setLoading(timelineState, append);
	
	try {
		const response = await fetchTimeline(100, append ? timelineState.offset : 0);
		timelineState = setTimelineData(timelineState, response.items, response.has_more, append);
	} catch (e) {
		timelineState = setError(timelineState, e instanceof Error ? e.message : 'Failed to load timeline');
	}
}

export async function loadTimelineConfig(): Promise<number> {
	try {
		const config = await fetchConfig();
		const minutes = config.refresh_minutes || 10;
		timelineState = setRefreshMinutes(timelineState, minutes);
		return minutes;
	} catch {
		return 10;
	}
}

export async function checkClusteringStatus(): Promise<boolean> {
	try {
		const status = await fetchStatus();
		return status.is_clustering;
	} catch {
		return false;
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
