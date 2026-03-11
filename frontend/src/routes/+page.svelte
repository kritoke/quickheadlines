<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import FeedTabs from '$lib/components/FeedTabs.svelte';
	import AppHeader from '$lib/components/AppHeader.svelte';
	import BitsSearchModal from '$lib/components/BitsSearchModal.svelte';
	import { fetchFeeds, fetchMoreFeedItems, fetchConfig } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { themeState, toggleEffects } from '$lib/stores/theme.svelte';
	import { websocketConnection } from '$lib/websocket';
	import { createFeedEffects } from '$lib/stores/effects.svelte';
	import { logger, initDebug, setDebugEnabled } from '$lib/utils/debug';
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

	let feedEffects: ReturnType<typeof createFeedEffects> | null = null;

	let filteredFeeds = $derived(getFilteredFeeds(searchQuery));

	let lastUpdated = $derived(
		feedState.lastUpdated ? new Date(feedState.lastUpdated) : null
	);

	let loading = $derived(isLoading(feedState) || isRefreshing(feedState));
	let error = $derived(isError(feedState) ? getError(feedState) : null);

	async function handleTabChange(tab: string) {
		if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
		
		tabChangeTimeout = setTimeout(async () => {
			const url = new URL(window.location.href);
			url.searchParams.set('tab', tab);
			window.history.replaceState({}, '', url);
			
			setActiveTab(tab);
			await loadFeeds(tab);
			
			requestAnimationFrame(() => {
				requestAnimationFrame(() => {
					document.body.scrollTop = 0;
					document.documentElement.scrollTop = 0;
					window.scrollTo(0, 0);
				});
			});
		}, 150);
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
					const saveScrollY = window.scrollY;
					loadFeeds(feedState.activeTab, true);
					window.scrollTo(0, saveScrollY);
				} else if (message.type === 'clustering_status') {
				}
			};
			websocketConnection.addEventListener(handleWebSocketMessage);

			return () => {
				if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
			};
		}
	});
	async function handleLogoClick() {
		const currentTab = feedState.activeTab;
		
		const url = new URL(window.location.href);
		url.searchParams.set('tab', currentTab);
		window.history.replaceState({}, '', url);
		
		await loadFeeds(currentTab, true);
		
		requestAnimationFrame(() => {
			requestAnimationFrame(() => {
				document.body.scrollTop = 0;
				document.documentElement.scrollTop = 0;
				window.scrollTo(0, 0);
			});
		});
	}
</script>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors duration-200" data-name="feeds-page">
	<AppHeader 
		title="QuickHeadlines"
		viewLink={{ href: '/timeline', icon: 'clock' }}
		{searchExpanded}
		onSearchToggle={() => searchExpanded = !searchExpanded}
		onLogoClick={handleLogoClick}
	>
		{#snippet metadata()}
			{#if lastUpdated}
				<span class="text-xs text-slate-500 dark:text-slate-400 hidden md:block whitespace-nowrap flex items-center gap-1">
					{#if isRefreshing(feedState)}
						<span class="inline-block w-2 h-2 bg-blue-500 rounded-full animate-pulse"></span>
					{/if}
					Updated {lastUpdated.toLocaleTimeString()}
				</span>
			{/if}
		{/snippet}
		
		{#snippet tabContent()}
			{#if feedState.tabs.length > 0}
				<FeedTabs tabs={feedState.tabs} activeTab={feedState.activeTab} onTabChange={handleTabChange} />
			{/if}
		{/snippet}
	</AppHeader>

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

	<main class="mx-auto px-4 md:px-8 xl:px-12 py-4 overflow-visible" style="padding-top: calc(var(--header-height, 6rem) + 1rem); max-width: 1800px;">
		{#if loading && feedState.feeds.length === 0}
			<div class="flex items-center justify-center py-20 gap-3">
				<div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
				<div class="text-slate-500 dark:text-slate-400">Loading feeds...</div>
			</div>
		{:else if error && feedState.feeds.length === 0}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 p-4 rounded-lg">
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
				<div class="sticky top-0 z-20 bg-white/80 dark:bg-slate-900/80 backdrop-blur-sm py-2 flex items-center justify-center gap-2">
					<div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-slate-600 dark:text-slate-400">Loading feeds...</span>
				</div>
			{/if}

			{#if filteredFeeds.length > 0}
				{#key feedState.activeTab}
					<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4">
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
