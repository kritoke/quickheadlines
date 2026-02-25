<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import FeedTabs from '$lib/components/FeedTabs.svelte';
	import AppHeader from '$lib/components/AppHeader.svelte';
	import SearchModal from '$lib/components/SearchModal.svelte';
	import { fetchFeeds, fetchMoreFeedItems, fetchConfig, fetchStatus } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';

	let feeds = $state<FeedResponse[]>([]);
	let tabs = $state<{ name: string }[]>([]);
	let activeTab = $state('all');
	let loading = $state(false);
	let error = $state<string | null>(null);
	let lastUpdated = $state<Date | null>(null);
	let saveScrollY = $state(0);

	let loadingFeeds = $state<Record<string, boolean>>({});
	let tabCache = $state<Record<string, { feeds: FeedResponse[], loaded: boolean }>>({});
	
	let refreshInterval: ReturnType<typeof setInterval> | null = null;
	let configRefreshInterval: ReturnType<typeof setInterval> | null = null;
	let refreshMinutes = $state(10);
	let configFetched = $state(false);
	let mounted = $state(false);
	let isRefreshing = $state(false);

	let searchQuery = $state('');
	let searchExpanded = $state(false);

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
			return;
		}

		try {
			loading = !isAutoRefresh;
			error = null;
			const response: FeedsPageResponse = await fetchFeeds(tab);
			const swReleases = response.software_releases || [];
			feeds = [...swReleases, ...(response.feeds || [])];
			tabs = response.tabs || [];
			activeTab = tab;
			lastUpdated = response.updated_at ? new Date(response.updated_at) : null;
			
			tabCache = {
				...tabCache,
				[tab]: { feeds, loaded: true }
			};
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load feeds';
		} finally {
			loading = false;
			isRefreshing = false;
		}
	}
	
	async function loadConfig() {
		try {
			const config = await fetchConfig();
			const newRefreshMinutes = config.refresh_minutes || 10;
			
			refreshMinutes = newRefreshMinutes;
			configFetched = true;
			
			if (refreshInterval) {
				clearInterval(refreshInterval);
			}
			refreshInterval = setInterval(() => {
				loadFeeds(activeTab, true);
			}, newRefreshMinutes * 60 * 1000);
			console.log('[Feeds] Refresh interval set to', newRefreshMinutes, 'minutes');
		} catch (e) {
			if (!refreshInterval) {
				refreshInterval = setInterval(() => {
					loadFeeds(activeTab, true);
				}, 10 * 60 * 1000);
			}
		}
	}

	async function handleTabChange(tab: string) {
		activeTab = tab;
		const url = new URL(window.location.href);
		url.searchParams.set('tab', tab);
		window.history.replaceState({}, '', url);
		
		await loadFeeds(tab);
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
					[activeTab]: { feeds, loaded: true }
				};
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load more items';
		} finally {
			loadingFeeds = { ...loadingFeeds, [feed.url]: false };
		}
	}
	
	$effect(() => {
		if (!mounted) {
			mounted = true;
			const params = new URLSearchParams(window.location.search);
			const urlTab = params.get('tab') || 'all';
			activeTab = urlTab;
			
			loadFeeds(urlTab, true);
			
			// Load config first, then set up interval with correct value
			loadConfig().then(() => {
				refreshInterval = setInterval(() => {
					loadFeeds(activeTab, true);
				}, refreshMinutes * 60 * 1000);
			});

			// Check for background refresh completion
			async function checkRefresh() {
				try {
					const status = await fetchStatus();
					if (status.is_refreshing) {
						saveScrollY = window.scrollY;
						// Wait for refresh to complete, then reload
						await new Promise(r => setTimeout(r, 5000));
						const currentStatus = await fetchStatus();
						if (!currentStatus.is_refreshing) {
							loadFeeds(activeTab, true);
							window.scrollTo(0, saveScrollY);
						}
					}
				} catch (e) {
					// Status check failed
				}
			}

			setInterval(checkRefresh, 10000);
			
			configRefreshInterval = setInterval(() => {
				loadConfig();
			}, 60000);
		}
		
		return () => {
			if (refreshInterval) clearInterval(refreshInterval);
			if (configRefreshInterval) clearInterval(configRefreshInterval);
		};
	});
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

	<SearchModal 
		open={searchExpanded}
		query={searchQuery}
		placeholder="Search feeds..."
		onClose={() => searchExpanded = false}
		onQueryChange={(value) => searchQuery = value}
	/>

	<main class="mx-auto px-4 md:px-8 xl:px-12 py-4 overflow-visible" style="padding-top: calc(var(--header-height, 8rem) + 2rem); max-width: 1800px;">
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
