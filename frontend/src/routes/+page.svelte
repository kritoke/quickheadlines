<script lang="ts">
	import FeedBox from '$lib/components/FeedBox.svelte';
	import TabBar from '$lib/components/TabBar.svelte';
	import { fetchFeeds, fetchMoreFeedItems } from '$lib/api';
	import type { FeedResponse, FeedsPageResponse } from '$lib/types';
	import { onMount } from 'svelte';

	let feeds = $state<FeedResponse[]>([]);
	let tabs = $state<{ name: string }[]>([]);
	let activeTab = $state('all');
	let loading = $state(true);
	let error = $state<string | null>(null);

	let totalHeadlines = $derived(
		feeds.reduce((acc, f) => acc + f.items.length, 0)
	);

	async function loadFeeds(tab: string = activeTab) {
		try {
			loading = true;
			error = null;
			const response: FeedsPageResponse = await fetchFeeds(tab);
			feeds = response.feeds;
			tabs = response.tabs;
			activeTab = response.active_tab;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load feeds';
			console.error('Failed to load feeds:', e);
		} finally {
			loading = false;
		}
	}

	async function handleTabChange(tab: string) {
		await loadFeeds(tab);
	}

	async function handleLoadMore(feed: FeedResponse) {
		try {
			const currentOffset = feed.items.length;
			const response = await fetchMoreFeedItems(feed.url, 10, currentOffset);
			
			const feedIndex = feeds.findIndex(f => f.url === feed.url);
			if (feedIndex !== -1) {
				feeds[feedIndex] = {
					...feeds[feedIndex],
					items: [...feeds[feedIndex].items, ...response.items.slice(currentOffset)],
					total_item_count: response.total_item_count
				};
				feeds = feeds;
			}
		} catch (e) {
			console.error('Failed to load more items:', e);
		}
	}

	onMount(() => {
		loadFeeds();
	});
</script>

<svelte:head>
	<title>QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen">
	<!-- Header -->
	<header class="sticky top-0 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 z-20">
		<div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
			<div class="flex items-center gap-3">
				<img src="/logo.svg" alt="Logo" class="w-8 h-8" />
				<h1 class="text-xl font-bold text-slate-900 dark:text-white">
					QuickHeadlines
				</h1>
			</div>
			<div class="flex items-center gap-4">
				<span class="text-sm text-slate-500 dark:text-slate-400">
					{totalHeadlines} headlines
				</span>
				<a href="/timeline" class="text-sm text-blue-600 dark:text-blue-400 hover:underline">
					Timeline
				</a>
			</div>
		</div>
	</header>

	<!-- Main Content -->
	<main class="max-w-7xl mx-auto px-4 py-4">
		{#if loading}
			<div class="flex items-center justify-center py-20">
				<div class="text-slate-500 dark:text-slate-400">Loading feeds...</div>
			</div>
		{:else if error}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 p-4 rounded-lg">
				{error}
				<button
					onclick={() => loadFeeds()}
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

			<!-- Feeds Grid (3-2-1 responsive) -->
			<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
				{#each feeds as feed (feed.url)}
					<FeedBox {feed} onLoadMore={() => handleLoadMore(feed)} />
				{/each}
			</div>

			{#if feeds.length === 0}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No feeds found. Check your configuration.
				</div>
			{/if}
		{/if}
	</main>
</div>
