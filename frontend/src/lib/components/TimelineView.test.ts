import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushSync, mount, unmount } from 'svelte';
import TimelineView from './TimelineView.svelte';
import { createMockTimelineItem, createMockClusterItem } from '$lib/test/test-utils';
import type { ClusterItemsResponse } from '$lib/types';

describe('TimelineView', () => {
	let mockFetchClusterItems: (id: string) => Promise<ClusterItemsResponse>;

	beforeEach(() => {
		vi.clearAllMocks();
		mockFetchClusterItems = vi.fn().mockImplementation((clusterId: string) => {
			return Promise.resolve({
				items: [createMockClusterItem({ id: 'c1', cluster_id: clusterId })],
				cluster_id: clusterId
			});
		});
	});

	afterEach(() => {
		vi.clearAllMocks();
	});

	it('renders timeline items', () => {
		const items = [
			createMockTimelineItem({ id: 'item-1', title: 'First Item' }),
			createMockTimelineItem({ id: 'item-2', title: 'Second Item' })
		];
		
		const component = mount(TimelineView, {
			target: document.body,
			props: { items, hasMore: false, fetchClusterItems: mockFetchClusterItems }
		});
		
		expect(document.body.textContent).toContain('First Item');
		expect(document.body.textContent).toContain('Second Item');
		
		unmount(component);
	});

	it('groups items by date', () => {
		const today = new Date();
		const yesterday = new Date(today);
		yesterday.setDate(yesterday.getDate() - 1);
		
		const items = [
			createMockTimelineItem({ title: 'Today Item', pub_date: today.getTime() }),
			createMockTimelineItem({ title: 'Yesterday Item', pub_date: yesterday.getTime() })
		];
		
		const component = mount(TimelineView, {
			target: document.body,
			props: { items, hasMore: false, fetchClusterItems: mockFetchClusterItems }
		});
		
		const dayGroups = document.body.querySelectorAll('.day-group');
		expect(dayGroups.length).toBe(2);
		
		unmount(component);
	});

	it('shows cluster size badge when cluster_size > 1', () => {
		const item = createMockTimelineItem({
			cluster_id: 'cluster-1',
			cluster_size: 5,
			is_representative: true
		});
		
		const component = mount(TimelineView, {
			target: document.body,
			props: { items: [item], hasMore: false, fetchClusterItems: mockFetchClusterItems }
		});
		
		expect(document.body.textContent).toContain('5 sources');
		
		unmount(component);
	});

	it('shows load more button when hasMore is true', () => {
		const items = [createMockTimelineItem()];
		
		const component = mount(TimelineView, {
			target: document.body,
			props: { items, hasMore: true, fetchClusterItems: mockFetchClusterItems }
		});
		
		expect(document.body.textContent).toContain('Load More');
		
		unmount(component);
	});

	it('triggers onLoadMore callback when load more clicked', () => {
		const onLoadMore = vi.fn();
		const items = [createMockTimelineItem()];
		
		const component = mount(TimelineView, {
			target: document.body,
			props: { items, hasMore: true, onLoadMore, fetchClusterItems: mockFetchClusterItems }
		});
		
		const button = document.body.querySelector('.load-more button');
		button?.click();
		flushSync();
		
		expect(onLoadMore).toHaveBeenCalledTimes(1);
		
		unmount(component);
	});
});
