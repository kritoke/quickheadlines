<script lang="ts">
	import AppHeader from '$lib/components/AppHeader.svelte';
	import LayoutPicker from '$lib/components/LayoutPicker.svelte';
	import { fetchTimeline, fetchConfig, fetchStatus } from '$lib/api';
	import type { TimelineItemResponse } from '$lib/types';
	import { SvelteSet } from 'svelte/reactivity';

	let LazyTimelineView: any = null;
	const loadTimelineView = async () => {
		if (!LazyTimelineView) {
			const { default: component } = await import('$lib/components/TimelineView.svelte');
			LazyTimelineView = component;
		}
		return LazyTimelineView;
	};

	let LazySearchModal: any = null;
	const loadSearchModal = async () => {
		if (!LazySearchModal) {
			const { default: component } = await import('$lib/components/SearchModal.svelte');
			LazySearchModal = component;
		}
		return LazySearchModal;
	};

	let items = $state<TimelineItemResponse[]>([]);
	let itemIds = $state(new SvelteSet<string>());
	let hasMore = $state(false);
	let loading = $state(true);
	let loadingMore = $state(false);
	let error = $state<string | null>(null);
	let offset = $state(0);
	let sentinelElement: HTMLDivElement | undefined = $state();
	let isClustering = $state(false);
	let isRefreshing = $state(false);
	let saveScrollY = $state(0);
	let clusteringCheckInterval: ReturnType<typeof setInterval> | null = null;
	
	let refreshInterval: ReturnType<typeof setInterval> | null = null;
	let refreshMinutes = $state(10);
	const limit = 100;

	let searchQuery = $state('');
	let searchExpanded = $state(false);

	let filteredItems = $derived.by(() => {
		if (!searchQuery.trim()) return [...items];
		const q = searchQuery.toLowerCase();
		return items.filter(item => 
			item.title.toLowerCase().includes(q) ||
			item.feed_title.toLowerCase().includes(q)
		);
	});
	
	async function loadConfig() {
		try {
			const config = await fetchConfig();
			const newRefreshMinutes = config.refresh_minutes || 10;
			
			refreshMinutes = newRefreshMinutes;
			
			if (refreshInterval) {
				clearInterval(refreshInterval);
			}
			refreshInterval = setInterval(() => {
				loadTimeline();
			}, newRefreshMinutes * 60 * 1000);
			console.log('[Timeline] Refresh interval set to', newRefreshMinutes, 'minutes');
		} catch (e) {
			if (!refreshInterval) {
				refreshInterval = setInterval(() => {
					loadTimeline();
				}, 10 * 60 * 1000);
			}
		}
	}

	async function loadTimeline(append: boolean = false) {
		if (!append && isRefreshing) return;
		
		try {
			if (append) {
				loadingMore = true;
			} else {
				isRefreshing = true;
				loading = true;
			}
			error = null;
			
			const response = await fetchTimeline(limit, offset);
			
			if (append) {
				const newItems = response.items.filter((item: TimelineItemResponse) => !itemIds.has(item.id));
				newItems.forEach((item: TimelineItemResponse) => itemIds.add(item.id));
				items = [...items, ...newItems];
			} else {
				itemIds = new SvelteSet(response.items.map((item: TimelineItemResponse) => item.id));
				items = response.items;
			}
			
			hasMore = response.has_more;
			offset += response.items.length;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load timeline';
		} finally {
			loading = false;
			loadingMore = false;
			isRefreshing = false;
		}
	}

	async function handleLoadMore() {
		if (!loadingMore && hasMore) {
			await loadTimeline(true);
		}
	}

	$effect(() => {
		if (!sentinelElement || !hasMore) return;
		
		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach(entry => {
					if (entry.isIntersecting && !loadingMore && hasMore) {
						handleLoadMore();
					}
				});
			},
			{ rootMargin: '500px' }
		);
		
		observer.observe(sentinelElement);
		
		return () => observer.disconnect();
	});

	let mounted = $state(false);
	let initialized = $state(false);
	let pollTimeoutId: ReturnType<typeof setTimeout> | null = null;
	let abortController: AbortController | null = null;
	
	$effect(() => {
		if (!initialized) {
			initialized = true;
			mounted = true;
			loadTimeline();
			loadConfig();
			
			let lastUpdate = Date.now();
			
			abortController = new AbortController();
			
			async function pollForUpdates() {
				if (abortController?.signal.aborted) return;
				
				try {
					const response = await fetch(`/api/events?last_update=${lastUpdate}`, {
						signal: abortController!.signal
					});
					
					if (abortController?.signal.aborted) return;
					
					const text = await response.text();
					const lines = text.split('\n');
					for (const line of lines) {
						if (line.startsWith('event: feed_update')) {
							const dataLine = lines.find(l => l.startsWith('data: '));
							if (dataLine) {
								const timestamp = parseInt(dataLine.replace('data: ', ''));
								if (timestamp > lastUpdate) {
									console.log('[Long-poll] Feed update received, reloading timeline...');
									lastUpdate = timestamp;
									saveScrollY = window.scrollY;
									await loadTimeline();
									window.scrollTo(0, saveScrollY);
								}
							}
						}
					}
				} catch (e) {
					if (e instanceof Error && e.name === 'AbortError') {
						return;
					}
					console.warn('[Long-poll] Poll failed, retrying in 1s:', e);
				}
				
				if (!abortController?.signal.aborted) {
					pollTimeoutId = setTimeout(pollForUpdates, 1000);
				}
			}
			
			pollForUpdates();

			async function checkClustering() {
				try {
					const status = await fetchStatus();
					
					if (status.is_clustering && !isClustering) {
						isClustering = true;
						clusteringCheckInterval = setInterval(checkClustering, 5000);
					} else if (!status.is_clustering && isClustering) {
						isClustering = false;
						if (clusteringCheckInterval) {
							clearInterval(clusteringCheckInterval);
							clusteringCheckInterval = null;
						}
						saveScrollY = window.scrollY;
						isRefreshing = false;
						await loadTimeline();
						window.scrollTo(0, saveScrollY);
					}
				} catch (e) {
					// Clustering check failed
				}
			}
			
			checkClustering();
		}
		
		return () => {
			mounted = false;
			abortController?.abort();
			abortController = null;
			if (refreshInterval) {
				clearInterval(refreshInterval);
				refreshInterval = null;
			}
			if (clusteringCheckInterval) {
				clearInterval(clusteringCheckInterval);
				clusteringCheckInterval = null;
			}
			if (pollTimeoutId) {
				clearTimeout(pollTimeoutId);
				pollTimeoutId = null;
			}
		};
	});
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors">
	<AppHeader 
		title="Timeline"
		viewLink={{ href: '/', icon: 'rss' }}
		{searchExpanded}
		onSearchToggle={() => searchExpanded = !searchExpanded}
	>
		{#snippet metadata()}
			<span class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 whitespace-nowrap">
				<span class="sm:hidden">{filteredItems.length}</span>
				<span class="hidden sm:inline">{filteredItems.length} items</span>
			</span>
		{/snippet}
		
		{#snippet actions()}
			<LayoutPicker />
		{/snippet}
	</AppHeader>

	{#if searchExpanded}
		{#await loadSearchModal()}
			<div></div>
		{:then SearchModal}
			<SearchModal 
				open={searchExpanded}
				query={searchQuery}
				placeholder="Search timeline..."
				onClose={() => searchExpanded = false}
				onQueryChange={(value) => searchQuery = value}
			/>
		{/await}
	{/if}

	<main class="max-w-[1800px] mx-auto px-4 md:px-8 xl:px-12 py-4 overflow-visible" style="padding-top: calc(var(--header-height, 4rem) + 2rem);">
		{#if loading && items.length === 0}
			<div class="flex items-center justify-center py-20">
				<div class="text-slate-500 dark:text-slate-400">Loading timeline...</div>
			</div>
		{:else if error && items.length === 0}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 p-4 rounded-lg">
				{error}
				<button
					onclick={() => loadTimeline()}
					class="ml-2 underline hover:no-underline"
				>
					Retry
				</button>
			</div>
		{:else}
			{#if filteredItems.length > 0}
				{#await loadTimelineView()}
					<div class="flex items-center justify-center py-8">
						<div class="text-slate-500 dark:text-slate-400">Loading timeline view...</div>
					</div>
				{:then TimelineView}
					<TimelineView items={filteredItems} {hasMore} onLoadMore={handleLoadMore} />
				{/await}
			{:else if searchQuery}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No results for "{searchQuery}". Try a different search term.
				</div>
			{/if}

			{#if loadingMore}
				<div class="text-center py-4">
					<span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
						<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-slate-500 dark:text-slate-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Loading more...
					</span>
				</div>
			{/if}
			
			{#if hasMore}
				<div bind:this={sentinelElement} class="h-1"></div>
			{/if}
		{/if}
	</main>
</div>
