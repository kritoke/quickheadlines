<script lang="ts">
	import TimelineView from '$lib/components/TimelineView.svelte';
	import { fetchTimeline, fetchConfig, fetchStatus } from '$lib/api';
	import type { TimelineItemResponse } from '$lib/types';
	import { themeState, toggleCoolMode, getCursorColors, getThemeAccentColors } from '$lib/stores/theme.svelte';
	import { SvelteSet } from 'svelte/reactivity';
	import ThemePicker from '$lib/components/ThemePicker.svelte';

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

	let cursorColors = $derived(getCursorColors(themeState.theme));
	let themeColors = $derived(getThemeAccentColors(themeState.theme));
	
	let refreshInterval: ReturnType<typeof setInterval> | null = null;
	let refreshMinutes = $state(10);
	const limit = 100;

	let searchQuery = $state('');
	let searchExpanded = $state(false);

	let filteredItems = $derived.by(() => {
		if (!searchQuery.trim()) return items;
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
			
			// Always update refreshMinutes
			refreshMinutes = newRefreshMinutes;
			
			// Always set/reset the interval with the new value
			if (refreshInterval) {
				clearInterval(refreshInterval);
			}
			refreshInterval = setInterval(() => {
				loadTimeline();
			}, newRefreshMinutes * 60 * 1000);
			console.log('[Timeline] Refresh interval set to', newRefreshMinutes, 'minutes');
		} catch (e) {
			// Use default if config fetch fails
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
	
	$effect(() => {
		if (!mounted) {
			mounted = true;
			loadTimeline();
			loadConfig(); // loadConfig now handles setting up the refresh interval
			
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
			if (refreshInterval) clearInterval(refreshInterval);
			if (clusteringCheckInterval) clearInterval(clusteringCheckInterval);
		};
	});
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors">
	<header class="fixed top-0 left-0 right-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20">
		<div class="max-w-7xl mx-auto px-2 sm:px-4">
			<div class="flex items-center justify-between py-2">
				<div class="flex items-center gap-2 sm:gap-3 min-w-0">
					<a href="/" class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0">
						<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
						<span class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">Timeline</span>
					</a>
					<span class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 whitespace-nowrap">
						<span class="sm:hidden">{filteredItems.length}</span>
						<span class="hidden sm:inline">{filteredItems.length} items</span>
					</span>
				</div>
				<div class="flex items-center gap-1 sm:gap-2">
					<button
						onclick={() => searchExpanded = !searchExpanded}
						class="md:hidden p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
						aria-label="Search"
						title="Search"
					>
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
					</button>
					<a 
						href="/" 
						class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
						aria-label="Feed view"
						title="Feeds"
					>
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path d="M4 11a9 9 0 0 1 9 9" />
							<path d="M4 4a16 16 0 0 1 16 16" />
							<circle cx="5" cy="19" r="1" fill="currentColor" />
						</svg>
					</a>
					<button
						onclick={toggleCoolMode}
						class="p-1.5 sm:p-2 rounded-lg transition-colors"
						style="background-color: {themeState.coolMode ? themeColors.bgSecondary : 'transparent'}; opacity: {themeState.coolMode ? 1 : 0.7};"
						aria-label="Toggle cursor trail"
						title="Cursor trail"
					>
						<svg 
							class="w-5 h-5 transition-all duration-200"
							class:drop-shadow-lg={themeState.coolMode}
							style="color: {themeState.coolMode ? cursorColors.primary : '#94a3b8'};"
							viewBox="0 0 24 24" 
							fill="currentColor"
						>
							<path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z" />
							<path d="M13 13l6 6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" />
						</svg>
					</button>
					<ThemePicker />
				</div>
			</div>
		</div>
	</header>

	{#if searchExpanded}
		<div class="md:hidden pt-12 px-2">
			<div class="relative">
				<input
					type="text"
					bind:value={searchQuery}
					placeholder="Search timeline..."
					class="w-full px-3 py-2 text-sm bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500"
				/>
				{#if searchQuery}
					<button
						onclick={() => searchQuery = ''}
						class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
					>
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				{/if}
			</div>
		</div>
	{/if}

	<div class="hidden md:block max-w-7xl mx-auto px-4 pt-2">
		<div class="relative max-w-md">
			<input
				type="text"
				bind:value={searchQuery}
				placeholder="Search timeline..."
				class="w-full px-3 py-2 text-sm bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500"
			/>
			{#if searchQuery}
				<button
					onclick={() => searchQuery = ''}
					class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			{/if}
		</div>
	</div>

	<main class="max-w-7xl mx-auto px-2 sm:px-4 py-4 pt-20 md:pt-2 overflow-visible">
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
				<TimelineView items={filteredItems} {hasMore} onLoadMore={handleLoadMore} />
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
