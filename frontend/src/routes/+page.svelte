<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import TabBar from '$lib/components/TabBar.svelte';
	import { fetchFeeds, fetchMoreFeedItems } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { themeState, toggleTheme } from '$lib/stores/theme.svelte';
	import { onMount } from 'svelte';

	let feeds = $state<FeedResponse[]>([]);
	let tabs = $state<{ name: string }[]>([]);
	let activeTab = $state('all');
	let loading = $state(false);
	let error = $state<string | null>(null);

	// Cache for each tab's data
	let tabCache = $state<Record<string, { feeds: FeedResponse[], loaded: boolean }>>({});

	async function loadFeeds(tab: string = activeTab, force: boolean = false) {
		// Check cache first
		if (!force && tabCache[tab]?.loaded) {
			feeds = tabCache[tab].feeds;
			activeTab = tab;
			return;
		}

		try {
			loading = true;
			error = null;
			const response: FeedsPageResponse = await fetchFeeds(tab);
			feeds = response.feeds || [];
			tabs = response.tabs || [];
			activeTab = tab;
			
			// Update cache
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
		// Update URL without reload
		const url = new URL(window.location.href);
		url.searchParams.set('tab', tab);
		window.history.replaceState({}, '', url);
		
		await loadFeeds(tab);
	}

	async function handleLoadMore(feed: FeedResponse) {
		try {
			const currentOffset = feed.items.length;
			const response = await fetchMoreFeedItems(feed.url, 10, currentOffset);
			
			const feedIndex = feeds.findIndex(f => f.url === feed.url);
			if (feedIndex !== -1) {
				const updatedFeed = {
					...feeds[feedIndex],
					items: [...feeds[feedIndex].items, ...response.items.slice(currentOffset)],
					total_item_count: response.total_item_count
				};
				feeds = feeds.map((f, i) => i === feedIndex ? updatedFeed : f);
				
				// Update cache
				tabCache = {
					...tabCache,
					[activeTab]: { feeds, loaded: true }
				};
			}
		} catch (e) {
			console.error('Failed to load more items:', e);
		}
	}

	// Auto-refresh at interval
	let refreshInterval: ReturnType<typeof setInterval>;
	
	onMount(() => {
		// Get tab from URL on initial load
		const params = new URLSearchParams(window.location.search);
		const urlTab = params.get('tab') || 'all';
		activeTab = urlTab;
		
		// Initial load
		loadFeeds(urlTab, true);
		
		// Set up auto-refresh (default 10 minutes)
		const refreshMinutes = 10; // TODO: Get from API config
		refreshInterval = setInterval(() => {
			// Force refresh current tab
			loadFeeds(activeTab, true);
		}, refreshMinutes * 60 * 1000);
		
		return () => {
			if (refreshInterval) clearInterval(refreshInterval);
		};
	});
</script>

<svelte:head>
	<title>QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors duration-200">
	<!-- Header -->
	<header class="sticky top-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20">
		<div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
			<div class="flex items-center gap-3">
				<a href="/?tab=all" class="flex items-center gap-2 hover:opacity-80 transition-opacity">
					<img src="/logo.svg" alt="Logo" class="w-8 h-8" />
					<h1 class="text-xl font-bold text-slate-900 dark:text-white">
						QuickHeadlines
					</h1>
				</a>
			</div>
			<div class="flex items-center gap-4">
				<a href="/timeline" class="text-sm text-blue-600 dark:text-blue-400 hover:underline">
					Timeline
				</a>
				<button
					onclick={toggleTheme}
					class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Toggle theme"
				>
					{#if themeState.theme === 'dark'}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
						</svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
						</svg>
					{/if}
				</button>
			</div>
		</div>
	</header>

	<!-- Main Content -->
	<main class="max-w-7xl mx-auto px-4 py-4">
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
			<!-- Tab Navigation -->
			{#if tabs.length > 0}
				<TabBar {tabs} {activeTab} onTabChange={handleTabChange} />
			{/if}

			<!-- Loading overlay for tab switch -->
			{#if loading}
				<div class="absolute inset-0 bg-white/50 dark:bg-slate-900/50 flex items-center justify-center z-10 pointer-events-none">
					<div class="text-slate-500 dark:text-slate-400">Loading...</div>
				</div>
			{/if}

			<!-- Feeds Grid (3-2-1 responsive) -->
			{#if feeds.length > 0}
				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
					{#each feeds as feed, i (`feed-${i}`)}
						<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} />
					{/each}
				</div>
			{:else}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No feeds found. Check your configuration.
				</div>
			{/if}
		{/if}
	</main>
</div>
