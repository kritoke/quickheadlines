<script lang="ts">
	import type { TimelineItemResponse, ClusterItemsResponse } from '$lib/types';
	import { fetchClusterItems as defaultFetchClusterItems, formatTimestamp } from '$lib/api';
	import ClusterExpansion from './ClusterExpansion.svelte';
	import { themeState, getThemeTokens } from '$lib/stores/theme.svelte';
	import { layoutState } from '$lib/stores/layout.svelte';
	import BorderBeam from './BorderBeam.svelte';

	interface Props {
		items: TimelineItemResponse[];
		hasMore: boolean;
		onLoadMore?: () => void;
		fetchClusterItems?: (id: string) => Promise<ClusterItemsResponse>;
	}

	let { items, hasMore, onLoadMore, fetchClusterItems = defaultFetchClusterItems }: Props = $props();
	let themeColors = $derived(getThemeTokens(themeState.theme).colors);

	let expandedClusterId = $state<string | null>(null);
	let clusterItems = $state<Record<string, TimelineItemResponse[]>>({});
	let clusterLoading = $state<Record<string, boolean>>({});

	let columns = $derived(layoutState.timelineColumns);

	const isIOS = typeof navigator !== 'undefined' && /iPad|iPhone|iPod/.test(navigator.userAgent);
	const beamThemes = ['cyberpunk', 'matrix', 'vaporwave', 'retro80s', 'dracula', 'ocean'] as const;
	type BeamTheme = typeof beamThemes[number];

	let showBorderBeam = $derived(!isIOS && beamThemes.includes(themeState.theme as BeamTheme));

	let beamColors: Record<BeamTheme, { from: string; to: string; via?: string }> = {
		matrix: { from: '#00ff00', to: '#22c55e' },
		cyberpunk: { from: '#ff00ff', to: '#00ffff' },
		vaporwave: { from: '#ff71ce', to: '#b967ff', via: '#01cdfe' },
		retro80s: { from: '#ff2e63', to: '#00d4ff' },
		dracula: { from: '#bd93f9', to: '#50fa7b', via: '#ff79c6' },
		ocean: { from: '#06b6d4', to: '#0ea5e9', via: '#22d3ee' }
	};

	let currentBeamColors = $derived(beamColors[themeState.theme as BeamTheme] || { from: '#ff00ff', to: '#00ffff' });

	const beamItemCount = 10;

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
				// Failed to fetch cluster items
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
		<div class="day-group mb-6">
			<h2 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-3 sticky top-16 bg-white dark:bg-slate-900 py-2 z-10">
				{date}
			</h2>
			
			<div class="grid gap-2 {gridClass} transition-all duration-200">
				{#each dateItems as item, i (`${date}-${item.id}`)}
					{@const globalIndex = groupStartIndex + i}
					<div 
						class="timeline-item bg-white dark:bg-slate-800 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden transition-all duration-200 relative"
						class:col-span-full={expandedClusterId === item.id && columns > 1}
					>
						{#if showBorderBeam && globalIndex < beamItemCount}
							<BorderBeam 
								colorFrom={currentBeamColors.from} 
								colorTo={currentBeamColors.to}
								colorVia={currentBeamColors.via}
								duration={5}
								size={250}
							/>
						{/if}
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
				type="button"
				onclick={onLoadMore}
				class="px-4 py-2 text-sm rounded-lg transition-colors"
				style="background-color: {themeColors.bgSecondary}; color: {themeColors.text}; border: 1px solid {themeColors.border};"
			>
				Load More
			</button>
		</div>
	{/if}
</div>
