<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import AppHeader from '$lib/components/AppHeader.svelte';
	import TabSelector from '$lib/components/TabSelector.svelte';
	import BitsSearchModal from '$lib/components/BitsSearchModal.svelte';
	import LayoutPicker from '$lib/components/LayoutPicker.svelte';
	import { fetchFeeds, fetchMoreFeedItems, fetchConfig } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { themeState, toggleEffects } from '$lib/stores/theme.svelte';
	import { websocketConnection } from '$lib/websocket';
	import { NavigationService } from '$lib/services/navigationService';
	import { createFeedEffects } from '$lib/stores/effects.svelte';
	import { logger, initDebug, setDebugEnabled } from '$lib/utils/debug';
	import { page } from '$app/stores';
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
	import { searchState, setSearchQuery, toggleSearch, closeSearch } from '$lib/stores/search.svelte';

	let LazySearchModal: typeof BitsSearchModal | null = null;
	const loadSearchModal = async () => {
		if (!LazySearchModal) {
			const { default: component } = await import('$lib/components/BitsSearchModal.svelte');
			LazySearchModal = component;
		}
		return LazySearchModal;
	};

	let tabChangeTimeout: ReturnType<typeof setTimeout> | null = null;

	let filteredFeeds = $derived(getFilteredFeeds(searchState.query));

	let lastUpdated = $derived(
		feedState.lastUpdated ? new Date(feedState.lastUpdated) : null
	);

	let loading = $derived(isLoading(feedState) || isRefreshing(feedState));
	let error = $derived(isError(feedState) ? getError(feedState) : null);
	let currentTab = $derived(feedState.activeTab);
	let timelineLink = $derived('/timeline?tab=' + currentTab);

	let feedGridClass = $derived(getFeedGridClass(layoutState.feedColumns));

	async function handleTabChange(tab: string) {
		await loadFeeds(tab);
		await NavigationService.navigateToFeeds(tab);
		window.scrollTo({ top: 0, behavior: 'smooth' });
	}

	async function handleLoadMore(feed: FeedResponse) {
		await loadMoreFeedItems(feed);
	}
	
	async function handleRetry() {
		await loadFeeds(feedState.activeTab, true);
	}
	
		$effect(() => {
		logger.log('[Page] $effect running, mounted:', feedState.status);
		const initialized = feedState.status !== 'idle' || feedState.feeds.length > 0;
		
		if (!initialized) {
			logger.log('[Page] Initializing, loading feeds...');
			const params = new URLSearchParams(window.location.search);
			const urlTab = params.get('tab') || 'all';
			
			loadFeeds(urlTab, true);
			loadFeedConfig();
			initDebug();
			
			websocketConnection.connect();
			const handleWebSocketMessage = (message: any) => {
				if (message.type === 'feed_update') {
					logger.log('[FeedPage] Feed update received, reloading...');
					const params = new URLSearchParams(window.location.search);
					const currentTab = params.get('tab') || 'all';
					loadFeeds(currentTab, true);
				} else if (message.type === 'clustering_status') {
				}
			};
			websocketConnection.addEventListener(handleWebSocketMessage);

			return () => {
				if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
				websocketConnection.removeEventListener(handleWebSocketMessage);
			};
		}
	});

	$effect(() => {
		const urlTab = $page.url?.searchParams.get('tab') ?? 'all';
		const alreadyLoaded = feedState.status !== 'idle' || feedState.feeds.length > 0;
		
		if (alreadyLoaded && urlTab !== feedState.activeTab) {
			logger.log('[Page] URL tab changed from', feedState.activeTab, 'to', urlTab, ', reloading...');
			loadFeeds(urlTab);
		}
	});
	
	async function handleLogoClick() {
		await NavigationService.navigateToGlobalFeeds();
	}
</script>

<div class="min-h-screen theme-bg-primary transition-colors duration-200" data-name="feeds-page">
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
		<div class="md:hidden fixed top-14 left-0 right-0 z-40 theme-bg-primary border-b theme-border">
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

	<main class="max-w-[1400px] mx-auto px-4 md:px-6 py-3 sm:py-5" style="padding-top: calc(var(--header-height, 3.5rem) + 0.25rem);">
		<div class="h-8 md:hidden"></div>
		
		{#if loading && feedState.feeds.length === 0}
			<div class="flex items-center justify-center py-24 gap-3">
				<div class="w-6 h-6 border-2 theme-accent-border border-t-transparent rounded-full animate-spin"></div>
				<span class="theme-text-secondary">Loading feeds...</span>
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
				<div class="sticky top-[var(--header-height,3.5rem)] z-20 theme-bg-primary/90 backdrop-blur-sm py-3 flex items-center justify-center gap-2 border-b theme-border">
					<div class="w-4 h-4 border-2 theme-accent-border border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm theme-text-secondary">Loading feeds...</span>
				</div>
			{/if}

				{#if filteredFeeds.length > 0}
				{#key feedState.activeTab}
					<div class="grid {feedGridClass} gap-3 sm:gap-4 md:gap-5 pt-2 sm:pt-4 md:pt-6">
						{#each filteredFeeds as feed, i (`feed-${i}`)}
							<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} loading={feedState.loadingFeeds[feed.url] ?? false} />
						{/each}
					</div>
				{/key}
			{:else if searchState.query}
				<div class="text-center py-24 text-slate-500 dark:text-slate-400">
					<p class="text-lg">No results for "{searchState.query}"</p>
					<p class="text-sm mt-2">Try a different search term</p>
				</div>
			{:else}
				<div class="text-center py-24 text-slate-500 dark:text-slate-400">
					<p class="text-lg">No feeds found</p>
					<p class="text-sm mt-2">Check your configuration</p>
				</div>
			{/if}
		{/if}
	</main>
</div>