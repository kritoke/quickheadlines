<script lang="ts">
	import type { TimelineItemResponse } from '$lib/types';
	import { fetchClusterItems, formatTimestamp } from '$lib/api';
	import ClusterExpansion from './ClusterExpansion.svelte';

	interface Props {
		items: TimelineItemResponse[];
		hasMore: boolean;
		onLoadMore?: () => void;
	}

	let { items, hasMore, onLoadMore }: Props = $props();

	let expandedClusterId = $state<string | null>(null);
	let clusterItems = $state<Record<string, TimelineItemResponse[]>>({});
	let clusterLoading = $state<Record<string, boolean>>({});

	async function toggleCluster(item: TimelineItemResponse): Promise<void> {
		if (!item.cluster_id) return;

		if (expandedClusterId === item.cluster_id) {
			expandedClusterId = null;
			return;
		}

		expandedClusterId = item.cluster_id;

		if (!clusterItems[item.cluster_id]) {
			clusterLoading = { ...clusterLoading, [item.cluster_id]: true };
			try {
				const response = await fetchClusterItems(item.cluster_id);
				clusterItems = {
					...clusterItems,
					[item.cluster_id]: response.items.map(s => ({
						id: s.id,
						title: s.title,
						link: s.link,
						pub_date: s.pub_date,
						feed_title: s.feed_title,
						feed_url: s.feed_url,
						feed_link: s.feed_link,
						favicon: s.favicon,
						favicon_data: s.favicon_data,
						header_color: s.header_color,
						is_representative: false,
						cluster_id: item.cluster_id,
						cluster_size: item.cluster_size
					}))
				};
			} catch (e) {
				console.error('Failed to fetch cluster items:', e);
			} finally {
				clusterLoading = { ...clusterLoading, [item.cluster_id]: false };
			}
		}
	}

	function getHeaderStyle(item: TimelineItemResponse): string {
		const bgColor = item.header_color || '#64748b';
		const textColor = item.header_text_color || '#ffffff';
		return `background-color: ${bgColor}; color: ${textColor};`;
	}

	function getFaviconSrc(item: TimelineItemResponse): string {
		if (item.favicon_data) {
			if (item.favicon_data.startsWith('internal:')) {
				const iconName = item.favicon_data.replace('internal:', '');
				if (iconName === 'code_icon') return '/code_icon.svg';
				return '/favicon.svg';
			}
			return item.favicon_data;
		}
		if (item.favicon) {
			if (item.favicon.startsWith('internal:')) return '/favicon.svg';
			return item.favicon;
		}
		return '/favicon.svg';
	}

	function groupByDate(items: TimelineItemResponse[]): Map<string, TimelineItemResponse[]> {
		const groups = new Map<string, TimelineItemResponse[]>();
		
		// Show items that are either:
		// 1. Not in a cluster (no cluster_id)
		// 2. The representative of their cluster (is_representative === true)
		const visibleItems = items.filter(item => 
			!item.cluster_id || item.is_representative === true
		);
		
		for (const item of visibleItems) {
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
	{#each groupIndex as [date, dateItems] (date)}
		<div class="day-group mb-6">
			<h2 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-3 sticky top-0 bg-white dark:bg-slate-900 py-2 z-10">
				{date}
			</h2>
			
			<div class="space-y-2">
				{#each dateItems as item (item.id)}
					<div class="timeline-item bg-white dark:bg-slate-800 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
						<!-- Item Header with Feed Info -->
						<div
							class="flex items-center gap-2 px-3 py-2 text-xs font-medium"
							style={getHeaderStyle(item)}
						>
							<div class="w-4 h-4 rounded bg-white/90 p-0.5 flex items-center justify-center shadow-sm">
								<img
									src={getFaviconSrc(item)}
									alt="{item.feed_title} favicon"
									class="w-3 h-3 rounded"
									onerror={(e) => {
										const target = e.target as HTMLImageElement;
										target.src = '/favicon.svg';
									}}
								/>
							</div>
							<span class="truncate">{item.feed_title}</span>
							{#if item.cluster_size && item.cluster_size > 1}
								<button
									type="button"
									onclick={() => toggleCluster(item)}
									class="ml-auto bg-white/20 hover:bg-white/30 px-1.5 py-0.5 rounded text-[10px] transition-colors cursor-pointer flex items-center gap-1"
									aria-label="Show {item.cluster_size} similar stories"
								>
									{item.cluster_size} sources
									{#if expandedClusterId === item.cluster_id}
										<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
										</svg>
									{:else}
										<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
										</svg>
									{/if}
								</button>
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

						<!-- Cluster Expansion -->
						{#if expandedClusterId === item.cluster_id && item.cluster_id}
							<ClusterExpansion
								items={clusterItems[item.cluster_id] || []}
								loading={clusterLoading[item.cluster_id]}
							/>
						{/if}
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
