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

	let LazySearchModal: any = null;
	const loadSearchModal = async () => {
		if (!LazySearchModal) {
			const { default: component } = await import('$lib/components/BitsSearchModal.svelte');
			LazySearchModal = component;
		}
		return LazySearchModal;
	};

	let feeds = $state<FeedResponse[]>([]);
	let tabs = $state<{ name: string }[]>([]);
	let activeTab = $state('all');
	let loading = $state(false);
	let error = $state<string | null>(null);
	let lastUpdated = $state<Date | null>(null);
	let saveScrollY = $state(0);

	let loadingFeeds = $state<Record<string, boolean>>({});
	let tabCache = $state<Record<string, { feeds: FeedResponse[], loaded: boolean, updatedAt: Date | null }>>({});
	const MAX_TAB_CACHE_SIZE = 10;
	
	let refreshMinutes = $state(10);
	let configFetched = $state(false);
	let mounted = $state(false);
	let isRefreshing = $state(false);

	let searchQuery = $state('');
	let searchExpanded = $state(false);
	let tabChangeTimeout: ReturnType<typeof setTimeout> | null = null;
	let pageVisible = $state(true);
	let feedEffects: ReturnType<typeof createFeedEffects> | null = null;

	let filteredFeeds = $derived.by(() => {
		if (!searchQuery.trim()) return feeds;
		const q = searchQuery.toLowerCase();
		return feeds.map(feed => ({
			...feed,
			items: feed.items.filter(item => 
				item.title.toLowerCase().includes(q) ||
				feed.title.toLowerCase().includes(q)
			)
		})).filter(feed => feed.items.length > 0);
	});

	async function loadFeeds(tab: string = activeTab, force: boolean = false) {
		const isAutoRefresh = force && tabCache[tab]?.loaded;
		if (isAutoRefresh) {
			isRefreshing = true;
		}

		if (!force && tabCache[tab]?.loaded) {
			feeds = tabCache[tab].feeds;
			activeTab = tab;
			lastUpdated = tabCache[tab].updatedAt;
			return;
		}

		try {
			loading = !isAutoRefresh;
			error = null;
			console.log('[loadFeeds] Fetching feeds for tab:', tab);
			const response: FeedsPageResponse = await fetchFeeds(tab);
			console.log('[loadFeeds] Got response, feeds count:', response.feeds?.length, 'swReleases:', response.software_releases?.length);
			const swReleases = response.software_releases || [];
			feeds = [...swReleases, ...(response.feeds || [])];
			tabs = response.tabs || [];
			lastUpdated = new Date(response.updated_at);
			console.log('[loadFeeds] Set feeds, total:', feeds.length);
			
			let newCache = {
				...tabCache,
				[tab]: { feeds, loaded: true, updatedAt: lastUpdated }
			};
			
			const keys = Object.keys(newCache);
			if (keys.length > MAX_TAB_CACHE_SIZE) {
				const sorted = keys.sort((a, b) => {
					const aTime = newCache[a].updatedAt?.getTime() ?? 0;
					const bTime = newCache[b].updatedAt?.getTime() ?? 0;
					return aTime - bTime;
				});
				const toRemove = keys.length - MAX_TAB_CACHE_SIZE;
				for (let i = 0; i < toRemove; i++) {
					delete newCache[sorted[i]];
				}
			}
			tabCache = newCache;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load feeds';
		} finally {
			loading = false;
			isRefreshing = false;
		}
	}
	
	async function updateRefreshConfig() {
		try {
			const config = await fetchConfig();
			const newRefreshMinutes = config.refresh_minutes || 10;
			
			if (newRefreshMinutes !== refreshMinutes) {
				refreshMinutes = newRefreshMinutes;
				console.log('[Feeds] Config refresh interval updated from feeds.yml:', newRefreshMinutes, 'minutes');
			}
			
			configFetched = true;
		} catch (e) {
			console.warn('[Feeds] Failed to load config from feeds.yml, using default 10 minute interval');
		}
	}

	async function handleTabChange(tab: string) {
		window.scrollTo(0, 0);
		
		if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
		
		tabChangeTimeout = setTimeout(async () => {
			activeTab = tab;
			const url = new URL(window.location.href);
			url.searchParams.set('tab', tab);
			window.history.replaceState({}, '', url);
			
			await loadFeeds(tab);
		}, 150);
	}

	async function handleLoadMore(feed: FeedResponse) {
		try {
			loadingFeeds = { ...loadingFeeds, [feed.url]: true };
			
			const currentOffset = feed.items.length;
			const response = await fetchMoreFeedItems(feed.url, 10, currentOffset);
			
			const feedIndex = feeds.findIndex(f => f.url === feed.url);
			if (feedIndex !== -1) {
				const updatedFeed = {
					...feeds[feedIndex],
					items: [...feeds[feedIndex].items, ...response.items],
					total_item_count: response.total_item_count
				};
				feeds = feeds.map((f, i) => i === feedIndex ? updatedFeed : f);
				
				tabCache = {
					...tabCache,
					[activeTab]: { feeds, loaded: true, updatedAt: lastUpdated }
				};
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load more items';
		} finally {
			loadingFeeds = { ...loadingFeeds, [feed.url]: false };
		}
	}
	
	$effect(() => {
		console.log('[Page] $effect running, mounted:', mounted);
		if (!mounted) {
			mounted = true;
			console.log('[Page] Initializing, loading feeds...');
			const params = new URLSearchParams(window.location.search);
			const urlTab = params.get('tab') || 'all';
			activeTab = urlTab;
			
			loadFeeds(urlTab, true);
			updateRefreshConfig();
			
			// Connect to WebSocket for real-time updates
			websocketConnection.connect();
			const handleWebSocketMessage = (message: any) => {
				if (message.type === 'feed_update') {
					console.log('[FeedPage] Feed update received, reloading...');
					saveScrollY = window.scrollY;
					loadFeeds(activeTab, true);
					window.scrollTo(0, saveScrollY);
				} else if (message.type === 'clustering_status') {
					// Handle clustering status if needed
				}
			};
			websocketConnection.addEventListener(handleWebSocketMessage);

			const handleVisibilityChange = () => {
				pageVisible = !document.hidden;
			};
			document.addEventListener('visibilitychange', handleVisibilityChange);

			return () => {
				if (tabChangeTimeout) clearTimeout(tabChangeTimeout);
				document.removeEventListener('visibilitychange', handleVisibilityChange);
			};
		}
	});

	function handleScrollToTop() {
		window.scrollTo({ top: 0, behavior: 'smooth' });
	}
</script>

<svelte:head>
	<title>QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors duration-200" data-name="feeds-page">
	<AppHeader 
		title="QuickHeadlines"
		viewLink={{ href: '/timeline', icon: 'clock' }}
		{searchExpanded}
		onSearchToggle={() => searchExpanded = !searchExpanded}
	>
		{#snippet metadata()}
			{#if lastUpdated}
				<span class="text-xs text-slate-500 dark:text-slate-400 hidden md:block whitespace-nowrap flex items-center gap-1">
					{#if isRefreshing}
						<span class="inline-block w-2 h-2 bg-blue-500 rounded-full animate-pulse"></span>
					{/if}
					Updated {lastUpdated.toLocaleTimeString()}
				</span>
			{/if}
		{/snippet}
		
		{#snippet tabContent()}
			{#if tabs.length > 0}
				<FeedTabs {tabs} {activeTab} onTabChange={handleTabChange} />
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
		{#if loading && feeds.length === 0}
			<div class="flex items-center justify-center py-20">
				<div class="text-slate-500 dark:text-slate-400">Loading feeds...</div>
			</div>
		{:else if error && feeds.length === 0}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 p-4 rounded-lg">
				{error}
				<button
					onclick={() => loadFeeds(activeTab, true)}
					class="ml-2 underline hover:no-underline"
				>
					Retry
				</button>
			</div>
		{:else}
			{#if loading}
				<div class="absolute inset-0 bg-white/50 dark:bg-slate-900/50 flex items-center justify-center z-10 pointer-events-none">
					<div class="text-slate-500 dark:text-slate-400">Loading...</div>
				</div>
			{/if}

			{#if filteredFeeds.length > 0}
				{#key activeTab}
					<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4">
						{#each filteredFeeds as feed, i (`feed-${i}`)}
							<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} loading={loadingFeeds[feed.url] ?? false} />
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