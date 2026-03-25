<script lang="ts">
	import AppHeader from '$lib/components/AppHeader.svelte';
	import TabSelector from '$lib/components/TabSelector.svelte';
	import LayoutPicker from '$lib/components/LayoutPicker.svelte';
	import BitsSearchModal from '$lib/components/BitsSearchModal.svelte';
	import { fetchFeeds, fetchTimeline, fetchConfig } from '$lib/api';
	import type { TimelineItemResponse, TabResponse } from '$lib/types';
	import { SvelteSet } from 'svelte/reactivity';
	import {
		createTimelineEffects,
	} from '$lib/stores/effects.svelte';
	import { logger, initDebug, setDebugEnabled } from '$lib/utils/debug';
	import { goto } from '$app/navigation';
	import { NavigationService } from '$lib/services/navigationService';
	import { page } from '$app/stores';
	import { themeState } from '$lib/stores/theme.svelte';
	import {
		timelineState,
		loadTimeline,
		loadTimelineConfig,
		handleLoadMore as doLoadMore,
		getFilteredItems,
		isLoading,
		isError,
		getError
	} from '$lib/stores/timelineStore.svelte';

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
			const { default: component } = await import('$lib/components/BitsSearchModal.svelte');
			LazySearchModal = component;
		}
		return LazySearchModal;
	};

	let searchQuery = $state('');
	let searchExpanded = $state(false);
	let tabs = $state<TabResponse[]>([]);
	let timelineEffects: ReturnType<typeof createTimelineEffects> | null = null;
	let initialized = $state(false);
	let sentinelElement: HTMLDivElement | undefined = $state();
	let visibilityHandler: (() => void) | null = null;
	
	let filteredItems = $derived(getFilteredItems(searchQuery));
	
	let loading = $derived(isLoading(timelineState));
	let error = $derived(isError(timelineState) ? getError(timelineState) : null);
	
	$effect(() => {
		if (!sentinelElement || !timelineState.hasMore) return;
		
		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach(entry => {
					if (entry.isIntersecting && !timelineState.loadingMore && timelineState.hasMore) {
						doLoadMore();
					}
				});
			},
			{ rootMargin: '500px' }
		);
		
		observer.observe(sentinelElement);
		
		return () => observer.disconnect();
	});
	
	let currentTab = $derived($page.url?.searchParams.get('tab') ?? 'all');
   
	$effect(() => {
		if (initialized) return;
		
		const currentTab = $page.url?.searchParams.get('tab') ?? 'all';
		
		(async () => {
			await loadTimeline(false, currentTab);
			await loadTimelineConfig();
			loadTabs();
			timelineEffects = createTimelineEffects();
			timelineEffects.start();
			document.addEventListener('visibilitychange', () => {});
			initialized = true;
		})();
	});
   
	$effect(() => {
		const urlTab = $page.url?.searchParams.get('tab') ?? 'all';
		if (initialized && urlTab !== timelineState.tabName) {
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
			const response = await fetchFeeds('all');
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

<div class="min-h-screen bg-white dark:bg-slate-950 transition-colors">
	<AppHeader 
		title="QuickHeadlines"
		tabs={tabs}
		activeTab={timelineState.tabName}
		onTabChange={handleTabChange}
		viewLink={{ href: '/', icon: 'rss' }}
		{searchExpanded}
		onSearchToggle={() => searchExpanded = !searchExpanded}
		onLogoClick={handleLogoClick}
	>
		<span class="text-sm text-slate-500 dark:text-slate-400">
			{filteredItems.length} items
		</span>
		
		{#snippet actions()}
			<LayoutPicker />
		{/snippet}
	</AppHeader>

	{#if tabs.length > 0}
		<div class="md:hidden fixed top-14 left-0 right-0 z-40 bg-white dark:bg-slate-950 border-b border-slate-200 dark:border-slate-800">
			<TabSelector 
				tabs={tabs}
				activeTab={timelineState.tabName}
				onTabChange={handleTabChange}
				maxInline={0}
			/>
		</div>
	{/if}

	{#if searchExpanded}
		{#await loadSearchModal()}
			<div></div>
		{:then SearchModal}
			<SearchModal 
				open={searchExpanded}
				query={searchQuery}
				placeholder="Search timeline..."
				onClose={() => searchExpanded = false}
				onQueryChange={(value: string) => searchQuery = value}
			/>
		{/await}
	{/if}

	<main class="max-w-[1400px] mx-auto px-4 md:px-6 py-3 sm:py-5" style="padding-top: calc(var(--header-height, 3.5rem) + 0.25rem);">
		<div class="h-8 md:hidden"></div>
		
		{#if loading && timelineState.items.length === 0}
			<div class="flex items-center justify-center py-24 gap-3">
				<div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
				<span class="text-slate-600 dark:text-slate-400">Loading timeline...</span>
			</div>
		{:else if error && timelineState.items.length === 0}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 px-4 py-3 rounded-xl">
				<span>{error}</span>
				<button
					onclick={handleRetry}
					class="ml-3 underline hover:no-underline font-medium"
				>
					Retry
				</button>
			</div>
		{:else}
			{#if loading && timelineState.items.length > 0}
				<div class="sticky top-[var(--header-height,3.5rem)] z-20 bg-white/90 dark:bg-slate-950/90 backdrop-blur-sm py-3 flex items-center justify-center gap-2 border-b border-slate-200 dark:border-slate-800">
					<div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-slate-600 dark:text-slate-400">Refreshing...</span>
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
			{:else if searchQuery}
				<div class="text-center py-24 text-slate-500 dark:text-slate-400">
					<p class="text-lg">No results for "{searchQuery}"</p>
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
			
			{#if timelineState.hasMore}
				<div bind:this={sentinelElement} class="h-1"></div>
			{/if}
		{/if}
	</main>
</div>