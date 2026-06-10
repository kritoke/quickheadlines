<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import AppHeader from '$lib/components/AppHeader.svelte';
	import TabSelector from '$lib/components/TabSelector.svelte';
	import LayoutPicker from '$lib/components/LayoutPicker.svelte';
	import type { FeedResponse } from '$lib/types';
	import { NavigationService } from '$lib/services/navigationService';
	import { createFeedEffects } from '$lib/stores/effects.svelte';
	import { logger, initDebug } from '$lib/utils/debug';
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import {
		feedState,
		loadFeeds,
		loadMoreFeedItems,
		loadFeedConfig,
		getFilteredFeeds,
		isLoading,
		isRefreshing,
		isError,
		getError
	} from '$lib/stores/feedStore.svelte';
	import { layoutState, getFeedGridClass } from '$lib/stores/layout.svelte';
	import { searchState, toggleSearch } from '$lib/stores/search.svelte';
	import { createLazyLoader } from '$lib/utils/lazyComponent';
	import { getStoredTab } from '$lib/stores/tabStore.svelte';

	const loadSearchModal = createLazyLoader(() => import('$lib/components/BitsSearchModal.svelte'));

	let tabChangeTimeout: ReturnType<typeof setTimeout> | null = null;

	// Track if feeds have ever been loaded successfully to distinguish between
	// "no feeds configured" vs "feeds failed temporarily"
	let hasEverLoadedFeeds = $state(false);

	let filteredFeeds = $derived(getFilteredFeeds(searchState.query));

	let loading = $derived(isLoading(feedState) || isRefreshing(feedState));
	let error = $derived(isError(feedState) ? getError(feedState) : null);

	let feedGridClass = $derived(getFeedGridClass(layoutState.feedColumns));

	async function handleTabChange(tab: string) {
		await NavigationService.navigateToFeeds(tab);
		window.scrollTo({ top: 0, behavior: 'smooth' });
	}

	async function handleLoadMore(feed: FeedResponse) {
		await loadMoreFeedItems(feed);
	}
	
	async function handleRetry() {
		await loadFeeds(feedState.activeTab, true);
	}
	
	let feedEffects: ReturnType<typeof createFeedEffects> | null = null;

	onMount(() => {
		const params = new URLSearchParams(window.location.search);
		const urlTab = params.get('tab') || getStoredTab();

		loadFeeds(urlTab, true);
		loadFeedConfig();
		initDebug();

		feedEffects = createFeedEffects();
		feedEffects.start();

		return () => {
			if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
			if (feedEffects) {
				feedEffects.stop();
				feedEffects = null;
			}
		};
	});

	$effect(() => {
		const urlTab = $page.url?.searchParams.get('tab') ?? getStoredTab();
		const alreadyLoaded = feedState.status !== 'idle' || feedState.feeds.length > 0;

		if (alreadyLoaded && urlTab !== feedState.activeTab) {
			logger.log('[Page] URL tab changed from', feedState.activeTab, 'to', urlTab, ', reloading...');
			loadFeeds(urlTab);
		}
	});
	
	// Track when feeds are successfully loaded
	$effect(() => {
		if (feedState.feeds.length > 0 && feedState.status === 'idle') {
			hasEverLoadedFeeds = true;
		}
	});
	
	// Computed: use current feeds, or empty array if never loaded
	let displayFeeds = $derived(
		hasEverLoadedFeeds ? filteredFeeds : []
	);
	
	async function handleLogoClick() {
		await NavigationService.navigateToGlobalFeeds();
	}
</script>

<div class="bg-surface-50 dark:bg-surface-950 transition-colors duration-200" data-name="feeds-page">
	<AppHeader 
		title="QuickHeadlines"
		tabs={feedState.tabs}
		activeTab={feedState.activeTab}
		onTabChange={handleTabChange}
		viewLink={{ href: '/timeline', icon: 'clock' }}
		searchExpanded={searchState.expanded}
		onSearchToggle={toggleSearch}
		onLogoClick={handleLogoClick}
	>
		{#snippet actions()}
			<LayoutPicker />
		{/snippet}
	</AppHeader>

	{#if feedState.tabs.length > 0}
		<div class="md:hidden sticky top-0 z-40 bg-surface-50 dark:bg-surface-950 border-b border-surface-200 dark:border-surface-700">
			<TabSelector 
				tabs={feedState.tabs}
				activeTab={feedState.activeTab}
				onTabChange={handleTabChange}
				maxInline={0}
			/>
		</div>
	{/if}

	{#if searchState.expanded}
		{#await loadSearchModal()}
			<div></div>
		{:then SearchModal}
			<SearchModal placeholder="Search feeds..." />
		{/await}
	{/if}

	<main class="flex-1 overflow-y-auto max-w-[1400px] mx-auto px-4 md:px-6 py-3 sm:py-5 w-full">

		
		{#if loading && feedState.feeds.length === 0}
			<div class="flex items-center justify-center py-24 gap-3">
				<div class="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
				<span class="text-surface-700 dark:text-surface-300">Loading feeds...</span>
			</div>
		{:else if error && feedState.feeds.length === 0}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 px-4 py-3 rounded-xl mx-4">
				<span>{error}</span>
				<button
					onclick={handleRetry}
					class="ml-3 underline hover:no-underline font-medium"
				>
					Retry
				</button>
			</div>
		{:else}
			{#if loading}
				<div class="sticky top-0 z-20 bg-surface-50 dark:bg-surface-950/90 backdrop-blur-sm py-3 flex items-center justify-center gap-2 border-b border-surface-200 dark:border-surface-700">
					<div class="w-4 h-4 border-2 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-surface-700 dark:text-surface-300">Loading feeds...</span>
				</div>
			{/if}

				{#if displayFeeds.length > 0}
				{#key feedState.activeTab}
					<div class="grid {feedGridClass} gap-3 sm:gap-4 md:gap-5 pt-2 sm:pt-4 md:pt-6">
						{#each displayFeeds as feed, i (`feed-${i}`)}
							<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} loading={feedState.loadingFeeds[feed.url] ?? false} />
						{/each}
					</div>
				{/key}
			{:else if searchState.query}
				<div class="text-center py-24 text-surface-500 dark:text-surface-400">
					<p class="text-lg">No results for "{searchState.query}"</p>
					<p class="text-sm mt-2">Try a different search term</p>
				</div>
			{:else if !hasEverLoadedFeeds}
				<div class="text-center py-24 text-surface-500 dark:text-surface-400">
					<p class="text-lg">No feeds found</p>
					<p class="text-sm mt-2">Check your configuration</p>
				</div>
			{:else}
				<!-- Feeds are being loaded or recently cleared, show subtle indicator -->
				<div class="text-center py-24 text-surface-400 dark:text-surface-500">
					<p class="text-sm">Refreshing feeds...</p>
				</div>
			{/if}
		{/if}
	</main>
</div>