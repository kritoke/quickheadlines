import type {
	FeedsPageResponse,
	TimelinePageResponse,
	ClustersResponse,
	ClusterItemsResponse,
	FeedResponse,
	ConfigResponse
} from './types';
import { toastStore } from './stores/toast.svelte';

const API_BASE = '/api';

const pendingRequests = new Map<string, Promise<any>>();

interface FetchOptions {
	method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
	timeout?: number;
	body?: object;
	errorContext?: string;
}

async function apiFetch<T>(url: string, options: FetchOptions = {}): Promise<T> {
	const { method = 'GET', timeout = 0, body, errorContext = 'Request' } = options;

	const fetchOptions: RequestInit = { method };
	if (body) {
		fetchOptions.headers = { 'Content-Type': 'application/json' };
		fetchOptions.body = JSON.stringify(body);
	}

	const controller = timeout > 0 ? new AbortController() : null;
	if (controller) {
		fetchOptions.signal = controller.signal;
		const timeoutId = setTimeout(() => controller.abort(), timeout);
		try {
			const response = await fetch(url, fetchOptions);
			clearTimeout(timeoutId);
			if (!response.ok) {
				throw new Error(`Failed to ${errorContext.toLowerCase()}: ${response.statusText}`);
			}
			return response.json();
		} catch (error) {
			clearTimeout(timeoutId);
			if (error instanceof Error && error.name === 'AbortError') {
				throw error;
			}
			const msg = error instanceof Error ? error.message : `Failed to ${errorContext.toLowerCase()}`;
			toastStore.error(msg, errorContext);
			throw error;
		}
	}

	try {
		const response = await fetch(url, fetchOptions);
		if (!response.ok) {
			throw new Error(`Failed to ${errorContext.toLowerCase()}: ${response.statusText}`);
		}
		return response.json();
	} catch (error) {
		if (error instanceof Error && error.name === 'AbortError') {
			throw error;
		}
		const msg = error instanceof Error ? error.message : `Failed to ${errorContext.toLowerCase()}`;
		toastStore.error(msg, errorContext);
		throw error;
	}
}

async function doFetchFeeds(tab: string, signal?: AbortSignal): Promise<FeedsPageResponse> {
	const url = `${API_BASE}/feeds?tab=${encodeURIComponent(tab)}`;
	
	// Create timeout controller
	const timeoutController = new AbortController();
	const timeoutId = setTimeout(() => timeoutController.abort(), 30000);
	
	// Set up abort handling
	const onAbort = () => {
		timeoutController.abort();
		clearTimeout(timeoutId);
	};
	signal?.addEventListener('abort', onAbort);
	
	try {
		// Use timeout controller's signal, or combined if external signal exists
		const fetchSignal = signal 
			? (signal.aborted ? signal : timeoutController.signal)
			: timeoutController.signal;
		
		const response = await fetch(url, { signal: fetchSignal });
		if (!response.ok) {
			throw new Error(`Failed to fetch feeds: ${response.statusText}`);
		}
		return response.json();
	} catch (error) {
		if (error instanceof Error && error.name === 'AbortError') {
			throw error;
		}
		const errorMessage = error instanceof Error ? error.message : 'Failed to fetch feeds';
		toastStore.error(errorMessage, 'Feed Error');
		throw error;
	} finally {
		clearTimeout(timeoutId);
		signal?.removeEventListener('abort', onAbort);
	}
}

export async function fetchFeeds(tab: string = 'all', signal?: AbortSignal): Promise<FeedsPageResponse> {
	// Don't dedupe when caller provides their own signal (they manage lifecycle)
	if (signal) {
		return doFetchFeeds(tab, signal);
	}
	
	const cacheKey = `feeds-${tab}`;
	
	if (pendingRequests.has(cacheKey)) {
		return pendingRequests.get(cacheKey)!;
	}
	
	const promise = doFetchFeeds(tab).finally(() => {
		pendingRequests.delete(cacheKey);
	});
	
	pendingRequests.set(cacheKey, promise);
	return promise;
}

export async function fetchTimeline(
	limit: number = 500,
	offset: number = 0,
	days: number = 14,
	cursor?: string,
	tab?: string
): Promise<TimelinePageResponse> {
	let url = `${API_BASE}/timeline?limit=${limit}&offset=${offset}&days=${days}`;
	if (cursor) {
		url += `&cursor=${cursor}`;
	}
	if (tab && tab !== 'all') {
		url += `&tab=${encodeURIComponent(tab)}`;
	}
	return apiFetch<TimelinePageResponse>(url, { errorContext: 'Fetch Timeline' });
}

export async function fetchClusters(): Promise<ClustersResponse> {
	const url = `${API_BASE}/clusters`;
	return apiFetch<ClustersResponse>(url, { errorContext: 'Fetch Clusters' });
}

export async function fetchClusterItems(clusterId: string): Promise<ClusterItemsResponse> {
	const url = `${API_BASE}/clusters/${clusterId}/items`;
	return apiFetch<ClusterItemsResponse>(url, { errorContext: 'Fetch Cluster Items' });
}

export async function fetchMoreFeedItems(
	feedUrl: string,
	limit: number = 10,
	offset: number = 0
): Promise<FeedResponse> {
	const url = `${API_BASE}/feed_more?url=${encodeURIComponent(feedUrl)}&limit=${limit}&offset=${offset}`;
	return apiFetch<FeedResponse>(url, { errorContext: 'Fetch More Items' });
}

export async function saveHeaderColor(
	feedUrl: string,
	color: string,
	textColor: string
): Promise<void> {
	const url = `${API_BASE}/header_color`;
	await apiFetch<void>(url, {
		method: 'POST',
		body: {
			feed_url: feedUrl,
			color,
			text_color: textColor
		},
		errorContext: 'Save Header Color'
	});
}

export function formatTimestamp(ms?: number): string {
	if (!ms) return '';
	const date = new Date(ms);
	const now = new Date();
	const diffMs = now.getTime() - date.getTime();
	const diffMins = Math.floor(diffMs / 60000);
	const diffHours = Math.floor(diffMs / 3600000);
	const diffDays = Math.floor(diffMs / 86400000);

	if (diffMins < 1) return 'just now';
	if (diffMins < 60) return `${diffMins}m ago`;
	if (diffHours < 24) return `${diffHours}h ago`;
	if (diffDays < 7) return `${diffDays}d ago`;
	
	return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function formatDate(ms?: number): string {
	if (!ms) return '';
	const date = new Date(ms);
	return date.toLocaleDateString('en-US', {
		weekday: 'long',
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	});
}

export async function fetchConfig(): Promise<ConfigResponse> {
	const url = `${API_BASE}/config`;
	return apiFetch<ConfigResponse>(url, { errorContext: 'Fetch Config' });
}
