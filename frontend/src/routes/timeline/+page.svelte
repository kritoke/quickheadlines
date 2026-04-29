<script lang="ts">
	import AppHeader from '$lib/components/AppHeader.svelte';
	import TabSelector from '$lib/components/TabSelector.svelte';
	import LayoutPicker from '$lib/components/LayoutPicker.svelte';
	import BitsSearchModal from '$lib/components/BitsSearchModal.svelte';
	import { fetchFeeds, fetchTabs } from '$lib/api';
	import type { TabResponse } from '$lib/types';
	import {
		createTimelineEffects,
	} from '$lib/stores/effects.svelte';
	import { logger } from '$lib/utils/debug';
	import { NavigationService } from '$lib/services/navigationService';
	import { page } from '$app/stores';
	import {
		timelineState,
		loadTimeline,
		loadTimelineConfig,
		handleLoadMore as doLoadMore,
		getFilteredItems,
		isLoading,
		isError,
		getError,
		cancelRetry
	} from '$lib/stores/timelineStore.svelte';
	import { searchState, setSearchQuery, toggleSearch } from '$lib/stores/search.svelte';
	import { createLazyLoader } from '$lib/utils/lazyComponent';
	import { onMount } from 'svelte';

	const loadTimelineView = createLazyLoader(() => import('$lib/components/TimelineView.svelte'));
	const loadSearchModal = createLazyLoader(() => import('$lib/components/BitsSearchModal.svelte'));

	let tabs = $state<TabResponse[]>([]);
	let timelineEffects: ReturnType<typeof createTimelineEffects> | null = null;
	let sentinelElement: HTMLDivElement | undefined = $state();
	
	let filteredItems = $derived(getFilteredItems(searchState.query));
	
	let loading = $derived(isLoading(timelineState));
	let error = $derived(isError(timelineState) ? getError(timelineState) : null);
	
	$effect(() => {
		const el = sentinelElement;
		const hasMore = timelineState.hasMore;
		if (!el || !hasMore) return;

		const observer = new IntersectionObserver(
			(entries) => {
				if (!timelineState.hasMore) return;
				entries.forEach(entry => {
					if (entry.isIntersecting && !timelineState.loadingMore) {
						doLoadMore();
					}
				});
			},
			{ rootMargin: '500px' }
		);

		observer.observe(el);

		return () => observer.disconnect();
	});
	
	let currentTab = $derived($page.url?.searchParams.get('tab') ?? 'all');
    
	onMount(() => {
		const currentTab = $page.url?.searchParams.get('tab') ?? 'all';
		
		(async () => {
			await Promise.all([
				loadTimeline(false, currentTab),
				loadTimelineConfig(),
				loadTabs()
			]);
			timelineEffects = createTimelineEffects();
			timelineEffects.start();
		})();
		
		return () => {
			if (timelineEffects) {
				timelineEffects.stop();
				timelineEffects = null;
			}
			cancelRetry();
		};
	});
    
	$effect(() => {
		const urlTab = $page.url?.searchParams.get('tab') ?? 'all';
		if (urlTab !== timelineState.tabName) {
			logger.log(`[Timeline] Tab changed from ${timelineState.tabName} to ${urlTab}, reloading...`);
			loadTimeline(false, urlTab);
		}
	});
	
	async function handleRetry() {
		const currentTab = $page.url?.searchParams.get('tab') ?? 'all';
		await loadTimeline(false, currentTab);
	}

	async function loadTabs() {
		try {
			const response = await fetchTabs();
			tabs = response.tabs;
		} catch (e) {
			logger.log('[Timeline] Failed to load tabs:', e);
		}
	}

	async function handleTabChange(tab: string) {
		await NavigationService.navigateToTimeline(tab);
	}

	function handleLogoClick() {
		NavigationService.navigateToFeeds();
	}
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="bg-surface-50 dark:bg-surface-950 transition-colors">
	<AppHeader 
		title="QuickHeadlines"
		tabs={tabs}
		activeTab={timelineState.tabName}
		onTabChange={handleTabChange}
		viewLink={{ href: '/', icon: 'rss' }}
		searchExpanded={searchState.expanded}
		onSearchToggle={toggleSearch}
		onLogoClick={handleLogoClick}
	>
		<span class="text-sm text-surface-500 dark:text-surface-400">
			{filteredItems.length} items
		</span>
		
		{#snippet actions()}
			<LayoutPicker />
		{/snippet}
	</AppHeader>

	{#if tabs.length > 0}
		<div class="md:hidden fixed top-14 left-0 right-0 z-40 bg-surface-50 dark:bg-surface-950 border-b border-surface-200 dark:border-surface-700">
			<TabSelector 
				tabs={tabs}
				activeTab={timelineState.tabName}
				onTabChange={handleTabChange}
				maxInline={0}
			/>
		</div>
	{/if}

	{#if searchState.expanded}
		{#await loadSearchModal()}
			<div></div>
		{:then SearchModal}
			<SearchModal placeholder="Search timeline..." />
		{/await}
	{/if}

	<main class="max-w-[1400px] mx-auto px-4 md:px-6 py-3 sm:py-5" style="padding-top: calc(var(--header-height, 3.5rem) + 0.25rem);">
		<div class="h-8 md:hidden"></div>
		
		{#if loading && timelineState.items.length === 0}
			<div class="flex items-center justify-center py-24 gap-3">
				<div class="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
				<span class="text-surface-700 dark:text-surface-300">Loading timeline...</span>
			</div>
		{:else if error && timelineState.items.length === 0}
			{#if timelineState.retryAfterMs > 0}
				<div class="bg-amber-50 dark:bg-amber-900/20 text-amber-700 dark:text-amber-400 px-4 py-3 rounded-xl flex items-center gap-2">
					<div class="w-4 h-4 border-2 border-amber-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm font-medium">Rate limited — retrying in {Math.ceil(timelineState.retryAfterMs / 1000)}s...</span>
				</div>
			{:else}
				<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 px-4 py-3 rounded-xl">
					<span>{error}</span>
					<button
						onclick={handleRetry}
						class="ml-3 underline hover:no-underline font-medium"
					>
						Retry
					</button>
				</div>
			{/if}
		{:else}
			{#if loading && timelineState.items.length > 0}
				<div class="sticky top-[var(--header-height,3.5rem)] z-20 bg-surface-50 dark:bg-surface-950/90 backdrop-blur-sm py-3 flex items-center justify-center gap-2 border-b border-surface-200 dark:border-surface-700">
					<div class="w-4 h-4 border-2 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-surface-700 dark:text-surface-300">Refreshing...</span>
				</div>
			{/if}

			{#if timelineState.isClustering}
				<div class="sticky top-[var(--header-height,3.5rem)] z-10 bg-amber-50 dark:bg-amber-900/20 py-2.5 flex items-center justify-center gap-2 mt-4 rounded-xl">
					<div class="w-4 h-4 border-2 border-amber-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-amber-700 dark:text-amber-400 font-medium">Grouping similar articles...</span>
				</div>
			{/if}

			{#if filteredItems.length > 0}
				{#await loadTimelineView()}
					<div class="flex items-center justify-center py-8">
						<span class="text-slate-500 dark:text-slate-400">Loading timeline view...</span>
					</div>
				{:then TimelineView}
					<div class="pt-4 md:pt-6">
						<TimelineView items={filteredItems} hasMore={timelineState.hasMore} onLoadMore={doLoadMore} />
					</div>
				{/await}
			{:else if searchState.query}
				<div class="text-center py-24 text-slate-500 dark:text-slate-400">
					<p class="text-lg">No results for "{searchState.query}"</p>
					<p class="text-sm mt-2">Try a different search term</p>
				</div>
			{/if}

			{#if timelineState.loadingMore}
				<div class="text-center py-6">
					<span class="inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
						<svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Loading more...
					</span>
				</div>
			{/if}
			
			<div bind:this={sentinelElement} class="h-1" class:h-0={!timelineState.hasMore} class:invisible={!timelineState.hasMore}></div>
		{/if}
	</main>
</div>