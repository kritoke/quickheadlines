import type {
	FeedsPageResponse,
	TimelinePageResponse,
	ClustersResponse,
	ClusterItemsResponse,
	FeedResponse,
	ConfigResponse,
	TabsResponse
} from './types';
import { toastStore } from './stores/toast.svelte';

const API_BASE = '/api';

export class RateLimitError extends Error {
	retryAfterMs: number;
	constructor(retryAfterMs: number) {
		super('Rate limit exceeded');
		this.name = 'RateLimitError';
		this.retryAfterMs = retryAfterMs;
	}
}

const pendingRequests = new Map<string, Promise<unknown>>();

const FETCH_TIMEOUT_MS = 30000;
const TIMELINE_FETCH_TIMEOUT_MS = 15000;
const MS_PER_MINUTE = 60000;
const MS_PER_HOUR = 3600000;
const MS_PER_DAY = 86400000;

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

	let timeoutId: ReturnType<typeof setTimeout> | undefined;
	if (timeout > 0) {
		const controller = new AbortController();
		fetchOptions.signal = controller.signal;
		timeoutId = setTimeout(() => controller.abort(), timeout);
	}

	try {
		const response = await fetch(url, fetchOptions);
		if (response.status === 429) {
			const retryAfter = parseInt(response.headers.get('Retry-After') || '5', 10);
			const err = new RateLimitError(Math.max(retryAfter, 1) * 1000);
			throw err;
		}
		if (!response.ok) {
			throw new Error(`Failed to ${errorContext.toLowerCase()}: ${response.statusText}`);
		}
		return response.json();
	} catch (error) {
		if (error instanceof RateLimitError) throw error;
		if (error instanceof Error && error.name === 'AbortError') throw error;
		const msg = error instanceof Error ? error.message : `Failed to ${errorContext.toLowerCase()}`;
		toastStore.error(msg, errorContext);
		throw error;
	} finally {
		if (timeoutId) clearTimeout(timeoutId);
	}
}

async function doFetchFeeds(tab: string): Promise<FeedsPageResponse> {
	const url = `${API_BASE}/feeds?tab=${encodeURIComponent(tab)}`;
	return apiFetch<FeedsPageResponse>(url, { timeout: FETCH_TIMEOUT_MS, errorContext: 'Fetch Feeds' });
}

export async function fetchFeeds(tab: string = 'all'): Promise<FeedsPageResponse> {
	const cacheKey = `feeds-${tab}`;
	
	if (pendingRequests.has(cacheKey)) {
		return pendingRequests.get(cacheKey) as Promise<FeedsPageResponse>;
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
	tab?: string
): Promise<TimelinePageResponse> {
	let url = `${API_BASE}/timeline?limit=${limit}&offset=${offset}&days=${days}`;
	if (tab) {
		url += `&tab=${encodeURIComponent(tab)}`;
	}
	return apiFetch<TimelinePageResponse>(url, { timeout: TIMELINE_FETCH_TIMEOUT_MS, errorContext: 'Fetch Timeline' });
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
	return apiFetch<FeedResponse>(url, { timeout: FETCH_TIMEOUT_MS, errorContext: 'Fetch More Items' });
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
	if (ms == null) return '';
	const date = new Date(ms);
	const now = new Date();
	const diffMs = now.getTime() - date.getTime();
	const diffMins = Math.floor(diffMs / MS_PER_MINUTE);
	const diffHours = Math.floor(diffMs / MS_PER_HOUR);
	const diffDays = Math.floor(diffMs / MS_PER_DAY);

	if (diffMins < 1) return 'just now';
	if (diffMins < 60) return `${diffMins}m ago`;
	if (diffHours < 24) return `${diffHours}h ago`;
	if (diffDays < 7) return `${diffDays}d ago`;
	
	return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function formatDate(ms?: number): string {
	if (ms == null) return '';
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

export async function fetchTabs(): Promise<TabsResponse> {
	const url = `${API_BASE}/tabs`;
	return apiFetch<TabsResponse>(url, { errorContext: 'Fetch Tabs' });
}
