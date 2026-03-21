<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import AppHeader from '$lib/components/AppHeader.svelte';
	import TabSelector from '$lib/components/TabSelector.svelte';
	import BitsSearchModal from '$lib/components/BitsSearchModal.svelte';
	import { fetchFeeds, fetchMoreFeedItems, fetchConfig } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { themeState, toggleEffects } from '$lib/stores/theme.svelte';
	import { websocketConnection } from '$lib/websocket';
	import { createFeedEffects } from '$lib/stores/effects.svelte';
	import { logger, initDebug, setDebugEnabled } from '$lib/utils/debug';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { setFeedsTab, getFeedsTab, resetScroll } from '$lib/stores/navigation.svelte';
	import {
		feedState,
		loadFeeds,
		loadMoreFeedItems,
		loadFeedConfig,
		setActiveTab,
		getFilteredFeeds,
		isLoading,
		isRefreshing,
		isError,
		getError
	} from '$lib/stores/feedStore.svelte';

	let LazySearchModal: typeof BitsSearchModal | null = null;
	const loadSearchModal = async () => {
		if (!LazySearchModal) {
			const { default: component } = await import('$lib/components/BitsSearchModal.svelte');
			LazySearchModal = component;
		}
		return LazySearchModal;
	};

	let searchQuery = $state('');
	let searchExpanded = $state(false);
	let tabChangeTimeout: ReturnType<typeof setTimeout> | null = null;
	let initialized = $state(false);

	let feedEffects: ReturnType<typeof createFeedEffects> | null = null;

	let filteredFeeds = $derived(getFilteredFeeds(searchQuery));

	let lastUpdated = $derived(
		feedState.lastUpdated ? new Date(feedState.lastUpdated) : null
	);

	let loading = $derived(isLoading(feedState) || isRefreshing(feedState));
	let error = $derived(isError(feedState) ? getError(feedState) : null);
	
	// Single source of truth: URL parameter
	let currentTab = $derived.by(() => {
		const urlTab = $page.url.searchParams.get('tab');
		return urlTab || 'all';
	});
	
	let timelineLink = $derived('/timeline?tab=' + currentTab);

	async function handleTabChange(tab: string) {
		if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
		
		tabChangeTimeout = setTimeout(async () => {
			// Update URL (single source of truth)
			const url = new URL(window.location.href);
			url.searchParams.set('tab', tab);
			history.replaceState({}, '', url.toString());
			
			// Sync state
			setActiveTab(tab);
			setFeedsTab(tab);
			
			// Scroll to top IMMEDIATELY when tab is clicked
			window.scrollTo(0, 0);
			document.documentElement.scrollTop = 0;
			document.body.scrollTop = 0;
			
			await loadFeeds(tab);
		}, 50);
	}

	async function handleLoadMore(feed: FeedResponse) {
		await loadMoreFeedItems(feed);
	}
	
	async function handleRetry() {
		await loadFeeds(currentTab, true);
	}
	
	// One-time initialization
	$effect(() => {
		if (initialized) return;
		initialized = true;
		
		logger.log('[Page] Initializing feeds...');
		
		// Load initial data with URL tab
		const urlTab = currentTab;
		setActiveTab(urlTab);
		setFeedsTab(urlTab);
		loadFeeds(urlTab, true);
		loadFeedConfig();
		initDebug();
		
		websocketConnection.connect();
		const handleWebSocketMessage = (message: any) => {
			if (message.type === 'feed_update') {
				logger.log('[FeedPage] Feed update received, reloading...');
				loadFeeds(currentTab, true);
			}
		};
		websocketConnection.addEventListener(handleWebSocketMessage);

		return () => {
			if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
		};
	});
	
	// Watch for URL tab changes (from timeline navigation) and sync
	$effect(() => {
		const urlTab = $page.url.searchParams.get('tab');
		if (urlTab && urlTab !== feedState.activeTab && initialized) {
			logger.log('[Page] URL tab changed to:', urlTab);
			setActiveTab(urlTab);
			setFeedsTab(urlTab);
			loadFeeds(urlTab);
		}
	});
	
	async function handleLogoClick() {
		const currentTab = feedState.activeTab;
		
		const url = new URL(window.location.href);
		url.searchParams.set('tab', currentTab);
		window.history.replaceState({}, '', url);
		
		await loadFeeds(currentTab, true);
	}
</script>

	<div class="min-h-screen theme-bg-primary transition-colors duration-200" data-name="feeds-page">
		<AppHeader 
			title="QuickHeadlines"
			tabs={feedState.tabs}
			activeTab={feedState.activeTab}
			onTabChange={handleTabChange}
			viewLink={{ href: timelineLink, icon: 'clock' }}
			activeView="feeds"
			{searchExpanded}
			onSearchToggle={() => searchExpanded = !searchExpanded}
			onLogoClick={handleLogoClick}
		/>

		<!-- Mobile tabs outside header -->
		{#if feedState.tabs.length > 0}
			<div class="md:hidden fixed top-14 left-0 right-0 z-40">
				<TabSelector 
					tabs={feedState.tabs}
					activeTab={feedState.activeTab}
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
				placeholder="Search feeds..."
				onClose={() => searchExpanded = false}
				onQueryChange={(value: string) => searchQuery = value}
			/>
		{/await}
	{/if}

	<main class="max-w-[1400px] mx-auto px-4 md:px-8 py-2 sm:py-4 overflow-visible md:py-6" style="padding-top: calc(var(--header-height, 3.5rem) + 0.5rem);">
		<!-- Spacer for mobile tabs -->
		<div class="h-8 md:hidden"></div>
		{#if loading && feedState.feeds.length === 0}
			<div class="flex items-center justify-center py-20 gap-3">
				<div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
				<div class="text-slate-500 dark:text-slate-400">Loading feeds...</div>
			</div>
		{:else if error && feedState.feeds.length === 0}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 p-4 rounded-lg mx-4">
				{error}
				<button
					onclick={handleRetry}
					class="ml-2 underline hover:no-underline"
				>
					Retry
				</button>
			</div>
		{:else}
			{#if loading}
				<div class="sticky top-0 z-20 theme-bg-primary/80 backdrop-blur-sm py-2 flex items-center justify-center gap-2">
					<div class="w-4 h-4 border-2 theme-accent border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm theme-text-secondary">Loading feeds...</span>
				</div>
			{/if}

			{#if filteredFeeds.length > 0}
				{#key feedState.activeTab}
					<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-3 mx-auto">
						{#each filteredFeeds as feed, i (`feed-${i}`)}
							<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} loading={feedState.loadingFeeds[feed.url] ?? false} />
						{/each}
					</div>
				{/key}
			{:else if searchQuery}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No results for "{searchQuery}". Try a different search term.
				</div>
			{:else}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No feeds found. Check your configuration.
				</div>
			{/if}
		{/if}
	</main>
</div>
