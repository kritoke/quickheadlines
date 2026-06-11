<script lang="ts">
	import type { TimelineItemResponse, ClusterItemsResponse } from '$lib/types';
	import { fetchClusterItems as defaultFetchClusterItems, formatTimestamp } from '$lib/api';
	import ClusterExpansion from './ClusterExpansion.svelte';
	import { isDarkTheme } from '$lib/stores/theme.svelte';
	import { readModeState } from '$lib/stores/readMode.svelte';
	import { layoutState } from '$lib/stores/layout.svelte';
	import { goto } from '$app/navigation';
	import { getFaviconSrc, getHeaderStyle } from '$lib/utils/feedItem';
	import { sanitizeUrl } from '$lib/utils/validation';
	import { getGridClass } from '$lib/tokens';
	import CommentIcon from './icons/CommentIcon.svelte';
	import DiscussionIcon from './icons/DiscussionIcon.svelte';

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
					<div
						class="timeline-item"
					>
						<!-- Item Header with Feed Info -->
						<div
							class="item-header"
							style={getHeaderStyle(item, isDark)}
						>
							<div class="favicon-wrapper">
								<img
									src={getFaviconSrc(item)}
									alt="{item.feed_title} favicon"
									class="favicon"
									onerror={(e) => {
										const target = e.target as HTMLImageElement;
										target.src = '/favicon.svg';
									}}
								/>
							</div>
							<span class="feed-title truncate">{item.feed_title}</span>
							{#if item.cluster_size && item.cluster_size > 1}
								<button
									type="button"
									onclick={() => toggleCluster(item)}
									class="cluster-button"
									aria-label="Show {item.cluster_size} similar stories"
								>
									{item.cluster_size} sources
									{#if expandedClusterId === item.cluster_id}
										<svg xmlns="http://www.w3.org/2000/svg" class="chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
										</svg>
									{:else}
										<svg xmlns="http://www.w3.org/2000/svg" class="chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
										</svg>
									{/if}
								</button>
							{/if}
						</div>
						
						<!-- Item Content -->
						<div class="item-content">
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
									class="read-mode-link"
								>
									<h3 class="item-title">{item.title}</h3>
								</button>
							{:else}
								<h3 class="item-title">
									<a
										href={sanitizeUrl(item.link)}
										target="_blank"
										rel="noopener noreferrer"
										class="title-link"
									>{item.title}</a>
								</h3>
							{/if}
							<div class="item-meta">
								<span class="timestamp">
									{formatTimestamp(item.pub_date)}
								</span>
								{#if item.comment_url}
									<a
										href={sanitizeUrl(item.comment_url)}
										target="_blank"
										rel="noopener noreferrer"
										title="Comments"
										class="icon-link"
									>
										<CommentIcon class="w-4 h-4" />
									</a>
								{/if}
								{#if item.commentary_url && item.commentary_url !== item.comment_url}
									<a
										href={sanitizeUrl(item.commentary_url)}
										target="_blank"
										rel="noopener noreferrer"
										title="Discussion"
										class="icon-link"
									>
										<DiscussionIcon class="w-4 h-4" />
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
								onRetry={() => retryCluster(item)}
							/>
						{/if}
					</div>
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
		top: var(--header-height, 3.5rem);
		background-color: var(--color-surface-50, #f9fafb);
		z-index: 10;
	}

	:global(.dark) .date-header {
		color: var(--color-surface-300, #d1d5db);
		background-color: var(--color-surface-950, #030712);
	}

	@media (min-width: 640px) {
		.date-header {
			top: var(--header-height, 3.5rem);
			font-size: 1.125rem;
		}
	}

	.items-grid {
		display: grid;
		gap: var(--spacing-sm, 0.5rem);
	}

	.timeline-item {
		display: flex;
		flex-direction: column;
		border-radius: var(--radius-lg, 0.75rem);
		border: 1px solid var(--color-surface-200, #e5e7eb);
		background-color: var(--color-surface-50, #f9fafb);
		overflow: hidden;
		transition: all 0.2s ease;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
	}

	:global(.dark) .timeline-item {
		border-color: var(--color-surface-700, #374151);
		background-color: var(--color-surface-900, #111827);
	}

	.item-header {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
		font-size: 0.75rem;
		font-weight: 500;
	}

	.favicon-wrapper {
		width: 1rem;
		height: 1rem;
		border-radius: var(--radius-sm, 0.125rem);
		padding: 0.125rem;
		background-color: rgb(255 255 255 / 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	:global(.dark) .favicon-wrapper {
		background-color: rgb(255 255 255 / 0.7);
	}

	.favicon {
		width: 0.75rem;
		height: 0.75rem;
		border-radius: var(--radius-sm, 0.125rem);
	}

	.feed-title {
		font-size: 0.75rem;
	}

	.cluster-button {
		margin-left: auto;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		border-radius: var(--radius-sm, 0.125rem);
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.15s ease;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		background-color: rgb(51 65 85 / 0.2);
		border: none;
	}

	.cluster-button:hover {
		background-color: rgb(51 65 85 / 0.3);
	}

	.cluster-button:active {
		background-color: rgb(51 65 85 / 0.4);
	}

	.chevron {
		width: 0.75rem;
		height: 0.75rem;
	}

	.item-content {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-xs, 0.25rem);
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
	}

	.item-title {
		font-size: 1rem;
		font-weight: 500;
		color: var(--color-surface-950, #030712);
		margin: 0;
		line-height: 1.4;
	}

	:global(.dark) .item-title {
		color: var(--color-surface-50, #f9fafb);
	}

	:global(.dark) .title-link {
		color: var(--color-surface-50, #f9fafb);
	}

	.read-mode-link {
		text-align: left;
		width: 100%;
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
	}

	.read-mode-link:hover .item-title {
		opacity: 0.8;
	}

	.title-link {
		color: inherit;
		text-decoration: none;
	}

	.title-link:hover {
		text-decoration: underline;
	}

	.item-meta {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
	}

	.timestamp {
		font-size: 0.875rem;
		color: var(--color-surface-700, #374151);
	}

	:global(.dark) .timestamp {
		color: var(--color-surface-300, #d1d5db);
	}

	.icon-link {
		padding: 0.125rem;
		color: var(--color-surface-700, #374151);
		transition: opacity 0.15s ease;
	}

	:global(.dark) .icon-link {
		color: var(--color-surface-300, #d1d5db);
	}

	.icon-link:hover {
		opacity: 0.8;
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
