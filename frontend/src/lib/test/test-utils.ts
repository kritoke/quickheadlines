import { vi } from 'vitest';
import type { FeedResponse, ItemResponse, TimelineItemResponse, ClusterItemsResponse } from '$lib/types';

// ============== Mock Data Factories ==============

export function createMockFeed(overrides: Partial<FeedResponse> = {}): FeedResponse {
	return {
		url: 'https://example.com/feed',
		title: 'Test Feed',
		site_link: 'https://example.com',
		items: [createMockItem()],
		total_item_count: 1,
		header_color: '#64748b',
		header_text_color: '#ffffff',
		...overrides
	};
}

export function createMockItem(overrides: Partial<ItemResponse> = {}): ItemResponse {
	return {
		title: 'Test Item',
		link: 'https://example.com/article',
		pub_date: Date.now(),
		...overrides
	};
}

export function createMockTimelineItem(overrides: Partial<TimelineItemResponse> = {}): TimelineItemResponse {
	return {
		id: 'item-1',
		title: 'Test Timeline Item',
		link: 'https://example.com/article',
		pub_date: Date.now(),
		feed_title: 'Test Feed',
		feed_url: 'https://example.com/feed',
		feed_link: 'https://example.com',
		is_representative: true,
		...overrides
	};
}

export function createMockClusterItem(overrides: Partial<ClusterItemsResponse['items'][number]> = {}): ClusterItemsResponse['items'][number] {
	return {
		id: 'cluster-item-1',
		title: 'Cluster Item',
		link: 'https://example.com/cluster',
		pub_date: Date.now(),
		feed_title: 'Test Feed',
		feed_url: 'https://example.com/feed',
		feed_link: 'https://example.com',
		header_color: '#64748b',
		...overrides
	};
}

export function createMockClusterItemsResponse(clusterId: string, items: ClusterItemsResponse['items'][number][] = []): ClusterItemsResponse {
	return {
		items: items.length > 0 ? items : [createMockClusterItem()],
		cluster_id: clusterId
	};
}

// ============== API Response Helpers ==============

export function mockApiResponse<T>(data: T): Response {
	return {
		ok: true,
		status: 200,
		statusText: 'OK',
		json: () => Promise.resolve(data),
		headers: new Headers(),
		text: () => Promise.resolve(JSON.stringify(data)),
	} as unknown as Response;
}

export function mockApiError(status: number, statusText: string): Response {
	return {
		ok: false,
		status,
		statusText,
		json: () => Promise.reject(new Error(statusText)),
		headers: new Headers(),
		text: () => Promise.reject(new Error(statusText)),
	} as unknown as Response;
}

// ============== Global Mocks ==============

const localStorageMock = (() => {
	let store: Record<string, string> = {};
	return {
		getItem: (key: string) => store[key] || null,
		setItem: (key: string, value: string) => { store[key] = value; },
		removeItem: (key: string) => { delete store[key]; },
		clear: () => { store = {}; }
	};
})();

export function setupLocalStorage() {
	Object.defineProperty(window, 'localStorage', { value: localStorageMock });
	return localStorageMock;
}

export function setupMatchMedia() {
	Object.defineProperty(window, 'matchMedia', {
		value: vi.fn().mockImplementation((query: string) => ({
			matches: false,
			media: query,
			addEventListener: vi.fn(),
			removeEventListener: vi.fn()
		}))
	});
}

export function setupGlobalMocks() {
	setupLocalStorage();
	setupMatchMedia();
	return { localStorage: localStorageMock };
}

export function clearGlobalMocks() {
	localStorageMock.clear();
	vi.restoreAllMocks();
}

// ============== Timer Helpers ==============

export function useFakeTimers() {
	vi.useFakeTimers();
}

export function useRealTimers() {
	vi.useRealTimers();
}

export async function advanceTimersByTime(ms: number) {
	vi.advanceTimersByTime(ms);
}

export async function runAllTimers() {
	vi.runAllTimers();
}
