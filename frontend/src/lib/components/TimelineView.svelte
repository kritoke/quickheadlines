<script lang="ts">
	import type { TimelineItemResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';

	interface Props {
		items: TimelineItemResponse[];
		hasMore: boolean;
		onLoadMore?: () => void;
	}

	let { items, hasMore, onLoadMore }: Props = $props();

	function getHeaderStyle(item: TimelineItemResponse): string {
		const isDark = document.documentElement.classList.contains('dark');
		
		if (item.header_color && item.header_text_color) {
			return `background-color: ${item.header_color}; color: ${item.header_text_color};`;
		}
		
		return '';
	}

	function getFaviconSrc(item: TimelineItemResponse): string {
		if (item.favicon_data) {
			return item.favicon_data;
		}
		if (item.favicon) {
			return item.favicon;
		}
		return '/favicon.svg';
	}

	function groupByDate(items: TimelineItemResponse[]): Map<string, TimelineItemResponse[]> {
		const groups = new Map<string, TimelineItemResponse[]>();
		
		for (const item of items) {
			const date = item.pub_date ? new Date(item.pub_date).toDateString() : 'Unknown Date';
			if (!groups.has(date)) {
				groups.set(date, []);
			}
			groups.get(date)!.push(item);
		}
		
		return groups;
	}

	let groupedItems = $derived(groupByDate(items));
	let groupIndex = $derived(Array.from(groupedItems.entries()));
</script>

<div class="timeline-view">
	{#each groupIndex as [date, dateItems], i}
		<div class="day-group mb-6">
			<h2 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-3 sticky top-0 bg-white dark:bg-slate-900 py-2 z-10">
				{date}
			</h2>
			
			<div class="space-y-2">
				{#each dateItems as item, j}
					<div class="timeline-item bg-white dark:bg-slate-800 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
						<!-- Item Header with Feed Info -->
						<div
							class="flex items-center gap-2 px-3 py-2 text-xs font-medium"
							style={getHeaderStyle(item)}
						>
							<img
								src={getFaviconSrc(item)}
								alt="{item.feed_title} favicon"
								class="w-4 h-4 rounded"
								onerror={(e) => {
									const target = e.target as HTMLImageElement;
									target.src = '/favicon.svg';
								}}
							/>
							<span class="truncate">{item.feed_title}</span>
							{#if item.cluster_size && item.cluster_size > 1}
								<span class="ml-auto bg-white/20 px-1.5 py-0.5 rounded text-[10px]">
									{item.cluster_size} sources
								</span>
							{/if}
						</div>
						
						<!-- Item Content -->
						<a
							href={item.link}
							target="_blank"
							rel="noopener noreferrer"
							class="block px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
						>
							<h3 class="text-sm font-medium text-slate-900 dark:text-slate-100 line-clamp-2">
								{item.title}
							</h3>
							<p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
								{formatTimestamp(item.pub_date)}
							</p>
						</a>
					</div>
				{/each}
			</div>
		</div>
	{/each}

	{#if hasMore}
		<div class="load-more text-center py-4">
			<button
				onclick={onLoadMore}
				class="px-4 py-2 bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded-lg hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors text-sm"
			>
				Load More
			</button>
		</div>
	{/if}
</div>
