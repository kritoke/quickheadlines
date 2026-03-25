import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushSync, mount, unmount } from 'svelte';
import FeedBox from './FeedBox.svelte';
import { createMockFeed, createMockItem } from '$lib/test/test-utils';

describe('FeedBox', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	afterEach(() => {
		vi.clearAllMocks();
	});

	it('renders feed title in header', () => {
		const feed = createMockFeed({ title: 'My Test Feed' });
		const component = mount(FeedBox, {
			target: document.body,
			props: { feed }
		});
		
		expect(document.body.textContent).toContain('My Test Feed');
		
		unmount(component);
	});

	it('renders feed items', () => {
		const feed = createMockFeed({
			items: [
				createMockItem({ title: 'First Item' }),
				createMockItem({ title: 'Second Item' })
			]
		});
		const component = mount(FeedBox, {
			target: document.body,
			props: { feed }
		});
		
		expect(document.body.textContent).toContain('First Item');
		expect(document.body.textContent).toContain('Second Item');
		
		unmount(component);
	});

	it('shows load more button when there are more items', () => {
		const feed = createMockFeed({
			items: Array.from({ length: 16 }, () => createMockItem()),
			total_item_count: 20
		});
		const component = mount(FeedBox, {
			target: document.body,
			props: { feed }
		});
		
		expect(document.body.textContent).toContain('Show');
		expect(document.body.textContent).toContain('more items');
		
		unmount(component);
	});

	it('calls onLoadMore when button clicked', () => {
		const onLoadMore = vi.fn();
		const feed = createMockFeed({
			items: Array.from({ length: 16 }, () => createMockItem()),
			total_item_count: 20
		});
		const component = mount(FeedBox, {
			target: document.body,
			props: { feed, onLoadMore }
		});
		
		const button = document.body.querySelector('[data-name="load-more"]') as HTMLElement;
		button?.click();
		flushSync();
		
		expect(onLoadMore).toHaveBeenCalledTimes(1);
		
		unmount(component);
	});
});