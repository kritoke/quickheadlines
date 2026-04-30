<script lang="ts">
	import type { TimelineItemResponse, ClusterItemsResponse } from '$lib/types';
	import { fetchClusterItems as defaultFetchClusterItems, formatTimestamp } from '$lib/api';
	import ClusterExpansion from './ClusterExpansion.svelte';
	import { themeState, isDarkTheme } from '$lib/stores/theme.svelte';
	import { readModeState } from '$lib/stores/readMode.svelte';
	import { layoutState } from '$lib/stores/layout.svelte';
	import { goto } from '$app/navigation';
	import { getFaviconSrc, getHeaderStyle } from '$lib/utils/feedItem';
	import { sanitizeUrl } from '$lib/utils/validation';


	interface Props {
		items: TimelineItemResponse[];
		hasMore: boolean;
		onLoadMore?: () => void;
		fetchClusterItems?: (id: string) => Promise<ClusterItemsResponse>;
	}

	let { items, hasMore, onLoadMore, fetchClusterItems = defaultFetchClusterItems }: Props = $props();
	let resolvedTheme = $derived(themeState.theme);
	let isDark = $derived(isDarkTheme());

	let expandedClusterId = $state<string | null>(null);
	let clusterItems = $state<Record<string, TimelineItemResponse[]>>({});
	let clusterLoading = $state<Record<string, boolean>>({});
	let clusterErrors = $state<Record<string, boolean>>({});

	let columns = $derived(layoutState.timelineColumns);

	function getGridClass(cols: number): string {
		if (cols <= 1) return 'grid-cols-1';
		if (cols === 2) return 'sm:grid-cols-2';
		if (cols === 3) return 'sm:grid-cols-2 lg:grid-cols-3';
		return 'sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4';
	}

	async function toggleCluster(item: TimelineItemResponse): Promise<void> {
		if (!item.cluster_id) return;

		if (expandedClusterId === item.cluster_id) {
			expandedClusterId = null;
			return;
		}

		expandedClusterId = item.cluster_id;

		if (!clusterItems[item.cluster_id]) {
			clusterLoading = { ...clusterLoading, [item.cluster_id]: true };
			clusterErrors = { ...clusterErrors, [item.cluster_id]: false };
			try {
				const response = await fetchClusterItems(item.cluster_id);
				clusterItems = {
					...clusterItems,
					[item.cluster_id]: response.items.map(story => ({
						id: story.id,
						title: story.title,
						link: story.link,
						pub_date: story.pub_date,
						feed_title: story.feed_title,
						feed_url: story.feed_url,
						feed_link: story.feed_link,
						favicon: story.favicon,
						favicon_data: story.favicon_data,
						header_color: story.header_color,
						is_representative: false,
						cluster_id: item.cluster_id,
						cluster_size: item.cluster_size
					}))
				};
			} catch (e) {
				clusterErrors = { ...clusterErrors, [item.cluster_id]: true };
			} finally {
				clusterLoading = { ...clusterLoading, [item.cluster_id]: false };
			}
		}
	}

	function retryCluster(item: TimelineItemResponse): void {
		delete clusterItems[item.cluster_id!];
		toggleCluster(item);
	}



	function groupByDate(items: TimelineItemResponse[]): Map<string, TimelineItemResponse[]> {
		const groups = new Map<string, TimelineItemResponse[]>();
		
		// Show items that are either:
		// 1. Not in a cluster (no cluster_id)
		// 2. The representative of their cluster (is_representative === true)
		const visibleItems = items.filter(item => 
			!item.cluster_id || item.is_representative
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
	
	let gridClass = $derived(getGridClass(columns));

	function getGroupStartIndex(groupIdx: number): number {
		let idx = 0;
		for (let i = 0; i < groupIdx; i++) {
			idx += groupIndex[i]?.[1]?.length ?? 0;
		}
		return idx;
	}
</script>

<div class="timeline-view" data-name="timeline-view">
	{#each groupIndex as [date, dateItems], groupIdx (date)}
		{@const groupStartIndex = getGroupStartIndex(groupIdx)}
		<div class="day-group mb-4 sm:mb-6">
			<h2 class="text-base sm:text-lg font-semibold text-surface-700 dark:text-surface-300 mb-2 sm:mb-3 sticky top-14 sm:top-16 bg-surface-50 dark:bg-surface-950 py-2 z-10">
				{date}
			</h2>
			
				<div class="grid gap-3 {gridClass} transition-all duration-200">
				{#each dateItems as item, i (`${date}-${item.id}`)}
					{@const globalIndex = groupStartIndex + i}
					<div 
						class="timeline-item rounded-lg shadow-sm overflow-hidden transition-all duration-200 relative"
						style="background-color: var(--color-surface-50); border: 1px solid var(--color-surface-200); touch-action: manipulation; -webkit-tap-highlight-color: transparent;"
					>
						<!-- Item Header with Feed Info -->
						<div
							class="flex items-center gap-2 px-3 py-2 text-xs font-medium"
							style={getHeaderStyle(item, isDark)}
						>
							<div class="w-4 h-4 rounded bg-white/80 dark:bg-white/70 p-0.5 flex items-center justify-center shadow-sm border border-white/20">
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
									class="ml-auto bg-[var(--color-primary-500,#334155)]/20 hover:bg-[var(--color-primary-500,#334155)]/30 active:bg-[var(--color-primary-500,#334155)]/40 px-2 py-1 rounded text-xs transition-colors cursor-pointer flex items-center gap-1"
									style="color: inherit; touch-action: manipulation; -webkit-tap-highlight-color: transparent;"
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
						<div class="block px-3 py-2 transition-colors gap-2">
							{#if readModeState.mode === 'read'}
								<button
									type="button"
									onclick={() => {
										const params = new URLSearchParams({
											url: item.link,
											title: item.title
										});
										goto(`/reader?${params.toString()}`);
									}}
									class="text-left w-full"
								>
									<h3 class="text-base font-medium text-surface-950 dark:text-surface-50 line-clamp-2 hover:opacity-80 transition-opacity">
										{item.title}
									</h3>
								</button>
							{:else}
								<h3 class="text-base font-medium text-surface-950 dark:text-surface-50 line-clamp-2">
									<a
										href={sanitizeUrl(item.link)}
										target="_blank"
										rel="noopener noreferrer"
										class="hover:underline"
									>{item.title}</a>
								</h3>
							{/if}
							<div class="flex items-center gap-2 mt-1">
								<p class="text-sm text-surface-700 dark:text-surface-300">
									{formatTimestamp(item.pub_date)}
								</p>
								{#if item.comment_url}
									<a
										href={sanitizeUrl(item.comment_url)}
										target="_blank"
										rel="noopener noreferrer"
										title="Comments"
										class="p-0.5 hover:opacity-80 transition-opacity"
									>
										<svg class="w-4 h-4 text-surface-700 dark:text-surface-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
											<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
										</svg>
									</a>
								{/if}
								{#if item.commentary_url && item.commentary_url !== item.comment_url}
									<a
										href={sanitizeUrl(item.commentary_url)}
										target="_blank"
										rel="noopener noreferrer"
										title="Discussion"
										class="p-0.5 hover:opacity-80 transition-opacity"
									>
										<svg class="w-4 h-4 text-surface-700 dark:text-surface-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
											<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
										</svg>
									</a>
								{/if}
							</div>
						</div>

						<!-- Cluster Expansion -->
						{#if expandedClusterId === item.cluster_id && item.cluster_id}
							<ClusterExpansion
								items={clusterItems[item.cluster_id] || []}
								loading={clusterLoading[item.cluster_id]}
								error={clusterErrors[item.cluster_id]}
								open={expandedClusterId === item.cluster_id}
								onRetry={() => retryCluster(item)}
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
				type="button"
				onclick={() => {
					onLoadMore?.();
				}}
				class="px-4 py-2 text-sm rounded-lg transition-colors bg-surface-100 dark:bg-surface-800 text-surface-950 dark:text-surface-50 border-surface-200 dark:border-surface-700"
			>
				Load More
			</button>
		</div>
	{/if}
</div>
