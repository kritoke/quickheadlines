<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import FeedTabs from '$lib/components/FeedTabs.svelte';
	import { fetchFeeds, fetchMoreFeedItems, fetchConfig, fetchStatus } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { themeState, toggleCoolMode, getCursorColors, getThemeAccentColors } from '$lib/stores/theme.svelte';
	import ThemePicker from '$lib/components/ThemePicker.svelte';

	let feeds = $state<FeedResponse[]>([]);
	let tabs = $state<{ name: string }[]>([]);
	let activeTab = $state('all');
	let loading = $state(false);
	let error = $state<string | null>(null);
	let lastUpdated = $state<Date | null>(null);
	let saveScrollY = $state(0);

	let loadingFeeds = $state<Record<string, boolean>>({});
	let tabCache = $state<Record<string, { feeds: FeedResponse[], loaded: boolean }>>({});

	let cursorColor = $derived(getCursorColors(themeState.theme).primary);
	let themeColors = $derived(getThemeAccentColors(themeState.theme));
	
	let refreshInterval: ReturnType<typeof setInterval> | null = null;
	let configRefreshInterval: ReturnType<typeof setInterval> | null = null;
	let refreshMinutes = $state(10);
	let configFetched = $state(false);
	let mounted = $state(false);
	let isRefreshing = $state(false);

	let searchQuery = $state('');

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
	<header class="fixed top-0 left-0 right-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-30" data-name="main-header">
		<div class="max-w-7xl mx-auto px-2 sm:px-4">
			<div class="flex items-center justify-between py-2">
				<div class="flex items-center gap-2 sm:gap-3 min-w-0">
					<a href="/?tab=all" class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0">
						<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
						<span class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">QuickHeadlines</span>
					</a>
					{#if lastUpdated}
						<span class="text-xs text-slate-500 dark:text-slate-400 hidden md:block whitespace-nowrap flex items-center gap-1">
							{#if isRefreshing}
								<span class="inline-block w-2 h-2 bg-blue-500 rounded-full animate-pulse"></span>
							{/if}
							Updated {lastUpdated.toLocaleTimeString()}
						</span>
					{/if}
				</div>
				<div class="flex items-center gap-1 sm:gap-2">
					<a 
						href="/timeline" 
						class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
						aria-label="Timeline view"
						title="Timeline"
					>
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10" />
							<polyline points="12 6 12 12 16 14" />
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
							style="color: {themeState.coolMode ? cursorColor : '#94a3b8'};"
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
			<div class="hidden md:block pb-2">
				{#if tabs.length > 0}
					<FeedTabs {tabs} {activeTab} onTabChange={handleTabChange} />
				{/if}
			</div>
		</div>
	</header>

	{#if tabs.length > 0}
		<div class="md:hidden pt-20">
			<FeedTabs {tabs} {activeTab} onTabChange={handleTabChange} />
		</div>
	{/if}

	<div class="hidden md:block max-w-7xl mx-auto px-4 pt-2">
		<div class="relative max-w-md">
			<input
				type="text"
				bind:value={searchQuery}
				placeholder="Search feeds..."
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

	<main class="max-w-7xl mx-auto px-2 sm:px-4 py-4 pt-0 md:pt-2 overflow-visible">
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
					<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
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
