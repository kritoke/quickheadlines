import type {
	FeedsPageResponse,
	TimelinePageResponse,
	ClustersResponse,
	ClusterItemsResponse,
	FeedResponse
} from './types';

const API_BASE = '/api';

export async function fetchFeeds(tab: string = 'all'): Promise<FeedsPageResponse> {
	const url = `${API_BASE}/feeds?tab=${encodeURIComponent(tab)}`;
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Failed to fetch feeds: ${response.statusText}`);
	}
	return response.json();
}

export async function fetchTimeline(
	limit: number = 500,
	offset: number = 0,
	days: number = 14
): Promise<TimelinePageResponse> {
	const url = `${API_BASE}/timeline?limit=${limit}&offset=${offset}&days=${days}`;
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Failed to fetch timeline: ${response.statusText}`);
	}
	return response.json();
}

export async function fetchClusters(): Promise<ClustersResponse> {
	const url = `${API_BASE}/clusters`;
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Failed to fetch clusters: ${response.statusText}`);
	}
	return response.json();
}

export async function fetchClusterItems(clusterId: string): Promise<ClusterItemsResponse> {
	const url = `${API_BASE}/clusters/${clusterId}/items`;
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Failed to fetch cluster items: ${response.statusText}`);
	}
	return response.json();
}

export async function fetchMoreFeedItems(
	feedUrl: string,
	limit: number = 10,
	offset: number = 0
): Promise<FeedResponse> {
	const url = `${API_BASE}/feed_more?url=${encodeURIComponent(feedUrl)}&limit=${limit}&offset=${offset}`;
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Failed to fetch more items: ${response.statusText}`);
	}
	return response.json();
}

export async function saveHeaderColor(
	feedUrl: string,
	color: string,
	textColor: string
): Promise<void> {
	const response = await fetch(`${API_BASE}/header_color`, {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json'
		},
		body: JSON.stringify({
			feed_url: feedUrl,
			color,
			text_color: textColor
		})
	});
	if (!response.ok) {
		throw new Error(`Failed to save header color: ${response.statusText}`);
	}
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
