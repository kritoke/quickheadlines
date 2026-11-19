<script lang="ts">
	import AppHeader from '#lib/components/AppHeader.svelte';
	import TabSelector from '#lib/components/TabSelector.svelte';
	import LayoutPicker from '#lib/components/LayoutPicker.svelte';
	import { fetchTabs } from '#lib/api';
	import type { TabResponse } from '#lib/types';
	import {
		createTimelineEffects,
	} from '#lib/stores/effects.svelte';
	import { logger } from '#lib/utils/debug';
	import { NavigationService } from '#lib/services/navigationService';
	import {
		timelineState,
		loadTimeline,
		handleLoadMore as doLoadMore,
		getFilteredItems,
		isLoading,
		isError,
		getError,
		cancelRetry,
		loadAllRemainingItems,
		isSearchLoadingAll
	} from '#lib/stores/timelineStore.svelte';
	import { searchState, toggleSearch } from '#lib/stores/search.svelte';
	import { createLazyLoader } from '#lib/utils/lazyComponent';
	import { onMount } from 'svelte';
	import { currentUrlTab, syncTabFromUrl } from '#lib/utils/urlTab.svelte';
	import StatusBanner from '#lib/components/StatusBanner.svelte';

	const loadTimelineView = createLazyLoader(() => import('#lib/components/TimelineView.svelte'));
	const loadSearchModal = createLazyLoader(() => import('#lib/components/BitsSearchModal.svelte'));

	const STICKY_BANNER =
		'sticky top-[var(--header-height,3.5rem)] z-20 bg-surface-50/80 dark:bg-surface-950/80 backdrop-blur-sm py-2 flex items-center justify-center gap-2';
	const BANNER_TEXT = 'text-sm text-surface-700 dark:text-surface-300';

	let tabs = $state<TabResponse[]>([]);
	let timelineEffects: ReturnType<typeof createTimelineEffects> | null = null;
	let sentinelElement: HTMLDivElement | undefined = $state();
	
	let filteredItems = $derived(getFilteredItems(searchState.query));
	
	$effect(() => {
		if (searchState.expanded && timelineState.tabName === 'all' && timelineState.hasMore && !timelineState.loadingMore) {
			loadAllRemainingItems();
		}
	});
	
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
	
	onMount(() => {
		loadTimeline(false, currentUrlTab());
		loadTabs();
		timelineEffects = createTimelineEffects();
		timelineEffects.start();

		return () => {
			if (timelineEffects) {
				timelineEffects.stop();
				timelineEffects = null;
			}
			cancelRetry();
		};
	});

	// React to later ?tab= changes; onMount handles the initial tab.
	syncTabFromUrl(
		() => timelineState.tabName,
		(tab) => {
			logger.log(`[Timeline] Tab changed from ${timelineState.tabName} to ${tab}, reloading...`);
			loadTimeline(false, tab);
		}
	);

	async function handleRetry() {
		await loadTimeline(false, currentUrlTab());
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
		<div class="md:hidden sticky top-[var(--header-height,3.5rem)] z-40 bg-surface-50 dark:bg-surface-950 border-b border-surface-200 dark:border-surface-700">
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

	<main class="max-w-[1400px] mx-auto px-4 md:px-6 py-3 sm:py-5 w-full">

		
		{#if loading && timelineState.items.length === 0}
			<div class="flex items-center justify-center py-24 gap-3">
				<div class="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
				<span class="text-surface-700 dark:text-surface-300">Loading timeline...</span>
			</div>
		{:else if error && timelineState.items.length === 0}
			{#if timelineState.retryAfterMs > 0}
				<StatusBanner
					tone="amber"
					class="bg-amber-50 dark:bg-amber-900/20 text-amber-700 dark:text-amber-400 px-4 py-3 rounded-xl flex items-center gap-2"
					textClass="text-sm font-medium"
					message="Rate limited — retrying in {Math.ceil(timelineState.retryAfterMs / 1000)}s..."
				/>
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
				<StatusBanner
					class="{STICKY_BANNER} border-b border-surface-200 dark:border-surface-700"
					textClass={BANNER_TEXT}
					message="Refreshing..."
				/>
			{:else if loading}
				<!-- Optimistic UI: show subtle indicator while keeping current content visible -->
				<StatusBanner
					class={STICKY_BANNER}
					textClass={BANNER_TEXT}
					message="Switching to {timelineState.tabName}..."
				/>
			{/if}

			{#if timelineState.isClustering}
				<StatusBanner
					tone="amber"
					class="sticky top-[var(--header-height,3.5rem)] z-10 bg-amber-50 dark:bg-amber-900/20 py-2.5 flex items-center justify-center gap-2 mt-4 rounded-xl"
					textClass="text-sm text-amber-700 dark:text-amber-400 font-medium"
					message="Grouping similar articles..."
				/>
			{/if}

			{#if filteredItems.length > 0}
				{#await loadTimelineView()}
					<div class="flex items-center justify-center py-8">
						<span class="text-slate-500 dark:text-slate-400">Loading timeline view...</span>
					</div>
				{:then TimelineView}
					<div class="pt-4 md:pt-6">
						<TimelineView items={filteredItems} hasMore={timelineState.hasMore} activeTab={timelineState.tabName} onLoadMore={doLoadMore} />
					</div>
				{/await}
		{:else if searchState.query && filteredItems.length === 0}
			{#if isSearchLoadingAll()}
				<div class="text-center py-24 text-slate-500 dark:text-slate-400">
					<div class="w-5 h-5 border-2 border-slate-400 border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
					<p class="text-lg">Searching all items...</p>
					<p class="text-sm mt-2">Loading remaining items to search</p>
				</div>
			{:else}
				<div class="text-center py-24 text-slate-500 dark:text-slate-400">
					<p class="text-lg">No results for "{searchState.query}"</p>
					<p class="text-sm mt-2">Try a different search term</p>
				</div>
			{/if}
			{/if}

			{#if timelineState.loadingMore}
				<!-- Optimistic UI: Show placeholder items while loading more -->
				<div class="space-y-3 py-6 animate-pulse">
					{#each Array(5) as _, i (i)}
						<div class="flex gap-3 p-3 rounded-xl bg-surface-100/50 dark:bg-surface-800/50">
							<div class="w-12 h-12 rounded-lg bg-surface-200 dark:bg-surface-700 flex-shrink-0"></div>
							<div class="flex-1 space-y-2">
								<div class="h-4 bg-surface-200 dark:bg-surface-700 rounded w-3/4"></div>
								<div class="h-3 bg-surface-200 dark:bg-surface-700 rounded w-1/2"></div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
			
			<div bind:this={sentinelElement} class="h-1" class:h-0={!timelineState.hasMore} class:invisible={!timelineState.hasMore}></div>
		{/if}
	</main>
</div>