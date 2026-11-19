<script lang="ts">
	import type { TimelineItemResponse, ClusterItemsResponse } from '#lib/types';
	import { fetchClusterItems as defaultFetchClusterItems } from '#lib/api';
	import TimelineItem from './TimelineItem.svelte';
	import { isDarkTheme } from '#lib/stores/theme.svelte';
	import { layoutState } from '#lib/stores/layout.svelte';
	import { getGridClass } from '#lib/tokens/grid';

	/**
	 * TimelineView Props
	 * 
	 * @property items - Array of timeline items to display
	 * @property hasMore - Whether there are more items to load
	 * @property activeTab - The currently active tab (used to detect tab changes)
	 * @property onLoadMore - Callback when user wants to load more items
	 * @property fetchClusterItems - Function to fetch cluster items (default provided)
	 */
	interface Props {
		items: TimelineItemResponse[];
		hasMore: boolean;
		activeTab?: string;
		onLoadMore?: () => void;
		fetchClusterItems?: (id: string) => Promise<ClusterItemsResponse>;
	}

	let { 
		items, 
		hasMore, 
		activeTab = 'all',
		onLoadMore, 
		fetchClusterItems = defaultFetchClusterItems 
	}: Props = $props();
	
	let isDark = $derived(isDarkTheme());

	// Cluster expansion state
	let expandedClusterId = $state<string | null>(null);
	let clusterItems = $state<Record<string, TimelineItemResponse[]>>({});
	let clusterLoading = $state<Record<string, boolean>>({});
	let clusterErrors = $state<Record<string, boolean>>({});

	/**
	 * Reset cluster expansion state when tab changes
	 * This is the CORRECT way to detect tab changes - using the tab identifier,
	 * not array length comparison (which was a hack)
	 */
	$effect(() => {
		const currentTab = activeTab;
		// Reset cluster state on tab change (except for initial load)
		if (currentTab) {
			expandedClusterId = null;
			clusterItems = {};
			clusterLoading = {};
			clusterErrors = {};
		}
	});

	// Get grid columns from layout state and use design tokens
	let columns = $derived(layoutState.timelineColumns);
	let gridClass = $derived(getGridClass(columns as 1 | 2 | 3 | 4));

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
					[item.cluster_id]: response.items.map((story) => ({
						...story,
						is_representative: false,
						cluster_id: item.cluster_id,
						cluster_size: item.cluster_size
					}))
				};
			} catch {
				clusterErrors = { ...clusterErrors, [item.cluster_id]: true };
			} finally {
				clusterLoading = { ...clusterLoading, [item.cluster_id]: false };
			}
		}
	}

	function retryCluster(item: TimelineItemResponse): void {
		if (!item.cluster_id) return;
		delete clusterItems[item.cluster_id];
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
</script>

<div class="timeline-view" data-name="timeline-view">
	{#each groupIndex as [date, dateItems] (date)}
		<div class="day-group">
			<h2 class="date-header">
				{date}
			</h2>
			
			<div class="items-grid {gridClass}">
				{#each dateItems as item (`${date}-${item.id}`)}
					<TimelineItem
						{item}
						{isDark}
						expanded={expandedClusterId === item.cluster_id}
						clusterItems={item.cluster_id ? clusterItems[item.cluster_id] || [] : []}
						clusterLoading={item.cluster_id ? clusterLoading[item.cluster_id] : false}
						clusterError={item.cluster_id ? clusterErrors[item.cluster_id] : false}
						onToggle={() => toggleCluster(item)}
						onRetry={() => retryCluster(item)}
					/>
				{/each}
			</div>
		</div>
	{/each}

	{#if hasMore}
		<div class="load-more">
			<button
				type="button"
				onclick={() => {
					onLoadMore?.();
				}}
				class="load-more-button"
			>
				Load More
			</button>
		</div>
	{/if}
</div>

<style>
	.timeline-view {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-lg, 1.5rem);
	}

	.day-group {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-md, 1rem);
	}

	.date-header {
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-surface-700, #374151);
		margin: 0;
		padding: var(--spacing-sm, 0.5rem) 0;
		position: sticky;
		top: 3.5rem;
		background-color: var(--color-surface-50, #f9fafb);
		z-index: 10;
	}

	:global(.dark) .date-header {
		color: var(--color-surface-300, #d1d5db);
		background-color: var(--color-surface-950, #030712);
	}

	@media (min-width: 640px) {
		.date-header {
			top: 4rem;
			font-size: 1.125rem;
		}
	}

	.items-grid {
		display: grid;
		gap: var(--spacing-sm, 0.5rem);
	}

	.load-more {
		display: flex;
		justify-content: center;
		padding: var(--spacing-md, 1rem) 0;
	}

	.load-more-button {
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
		font-size: 0.875rem;
		border-radius: var(--radius-md, 0.5rem);
		background-color: var(--color-surface-100, #f3f4f6);
		color: var(--color-surface-950, #030712);
		border: 1px solid var(--color-surface-200, #e5e7eb);
		transition: background-color 0.15s ease;
		cursor: pointer;
	}

	:global(.dark) .load-more-button {
		background-color: var(--color-surface-800, #1f2937);
		color: var(--color-surface-50, #f9fafb);
		border-color: var(--color-surface-700, #374151);
	}

	.load-more-button:hover {
		opacity: 0.9;
	}
</style>
