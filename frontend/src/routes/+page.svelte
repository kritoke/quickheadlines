<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import FeedTabs from '$lib/components/FeedTabs.svelte';
	import CursorTrail from '$lib/components/CursorTrail.svelte';
	import { fetchFeeds, fetchMoreFeedItems, fetchConfig } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { themeState, toggleCursorTrail } from '$lib/stores/theme.svelte';
	import { onMount } from 'svelte';
	import AnimatedThemeToggler from '$lib/components/AnimatedThemeToggler.svelte';

	let feeds = $state<FeedResponse[]>([]);
	let tabs = $state<{ name: string }[]>([]);
	let activeTab = $state('all');
	let loading = $state(false);
	let error = $state<string | null>(null);
	let lastUpdated = $state<Date | null>(null);

	let loadingFeeds = $state<Record<string, boolean>>({});
	let tabCache = $state<Record<string, { feeds: FeedResponse[], loaded: boolean }>>({});

	async function loadFeeds(tab: string = activeTab, force: boolean = false) {
		if (!force && tabCache[tab]?.loaded) {
			feeds = tabCache[tab].feeds;
			activeTab = tab;
			return;
		}

		try {
			loading = true;
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
			console.error('Failed to load more items:', e);
		} finally {
			loadingFeeds = { ...loadingFeeds, [feed.url]: false };
		}
	}

	let refreshInterval: ReturnType<typeof setInterval>;
	let configRefreshInterval: ReturnType<typeof setInterval>;
	let refreshMinutes = $state(10);
	let configFetched = $state(false);
	
	async function loadConfig() {
		try {
			const config = await fetchConfig();
			const newRefreshMinutes = config.refresh_minutes || 10;
			
			if (configFetched && newRefreshMinutes !== refreshMinutes) {
				console.log(`Config changed: refresh interval updated from ${refreshMinutes} to ${newRefreshMinutes} minutes`);
				if (refreshInterval) {
					clearInterval(refreshInterval);
					refreshInterval = setInterval(() => {
						loadFeeds(activeTab, true);
					}, newRefreshMinutes * 60 * 1000);
				}
			}
			
			refreshMinutes = newRefreshMinutes;
			configFetched = true;
		} catch (e) {
			console.warn('Failed to fetch config, using existing refresh rate:', e);
		}
	}
	
	onMount(async () => {
		const params = new URLSearchParams(window.location.search);
		const urlTab = params.get('tab') || 'all';
		activeTab = urlTab;
		
		loadFeeds(urlTab, true);
		
		await loadConfig();
		
		refreshInterval = setInterval(() => {
			loadFeeds(activeTab, true);
		}, refreshMinutes * 60 * 1000);
		
		configRefreshInterval = setInterval(() => {
			loadConfig();
		}, 60000);
		
		return () => {
			if (refreshInterval) clearInterval(refreshInterval);
			if (configRefreshInterval) clearInterval(configRefreshInterval);
		};
	});
</script>

<svelte:head>
	<title>QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors duration-200">
	<CursorTrail />
	
	<header class="fixed top-0 left-0 right-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-30">
		<div class="max-w-7xl mx-auto px-2 sm:px-4 py-2 sm:py-3 flex items-center justify-between">
			<div class="flex items-center gap-2 sm:gap-3 min-w-0">
				<a href="/?tab=all" class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0">
					<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
					<span class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">QuickHeadlines</span>
				</a>
				{#if lastUpdated}
					<span class="text-xs text-slate-500 dark:text-slate-400 hidden md:block whitespace-nowrap">
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
					onclick={toggleCursorTrail}
					class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Toggle cursor trail"
					title="Cursor trail"
				>
					<svg 
						class="w-5 h-5"
						class:text-accent={themeState.cursorTrail}
						class:text-slate-400={!themeState.cursorTrail}
						class:dark:text-slate-500={!themeState.cursorTrail}
						viewBox="0 0 24 24" 
						fill="currentColor"
					>
						<path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z" />
						<path d="M13 13l6 6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" />
					</svg>
				</button>
				<AnimatedThemeToggler class="p-1.5 sm:p-2" title="Toggle theme" />
			</div>
		</div>
	</header>

	<main class="max-w-7xl mx-auto px-2 sm:px-4 py-4 pt-20 sm:pt-20 overflow-visible">
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
			{#if tabs.length > 0}
				<FeedTabs {tabs} bind:activeTab={activeTab} onTabChange={handleTabChange} />
			{/if}

			{#if loading}
				<div class="absolute inset-0 bg-white/50 dark:bg-slate-900/50 flex items-center justify-center z-10 pointer-events-none">
					<div class="text-slate-500 dark:text-slate-400">Loading...</div>
				</div>
			{/if}

			{#if feeds.length > 0}
				{#key activeTab}
					<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
						{#each feeds as feed, i (`feed-${i}`)}
							<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} loading={loadingFeeds[feed.url] ?? false} />
						{/each}
					</div>
				{/key}
			{:else}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No feeds found. Check your configuration.
				</div>
			{/if}
		{/if}
	</main>
</div>
