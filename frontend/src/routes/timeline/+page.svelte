<script lang="ts">
	import TimelineView from '$lib/components/TimelineView.svelte';
	import { fetchTimeline } from '$lib/api';
	import type { TimelineItemResponse } from '$lib/types';
	import { onMount } from 'svelte';

	let items = $state<TimelineItemResponse[]>([]);
	let hasMore = $state(false);
	let loading = $state(true);
	let loadingMore = $state(false);
	let error = $state<string | null>(null);
	let offset = $state(0);
	const limit = 100;

	async function loadTimeline(append: boolean = false) {
		try {
			if (append) {
				loadingMore = true;
			} else {
				loading = true;
			}
			error = null;
			
			const response = await fetchTimeline(limit, offset);
			
			if (append) {
				items = [...items, ...response.items];
			} else {
				items = response.items;
			}
			
			hasMore = response.hasMore;
			offset += response.items.length;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load timeline';
			console.error('Failed to load timeline:', e);
		} finally {
			loading = false;
			loadingMore = false;
		}
	}

	async function handleLoadMore() {
		await loadTimeline(true);
	}

	onMount(() => {
		loadTimeline();
	});
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen">
	<!-- Header -->
	<header class="sticky top-0 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 z-20">
		<div class="max-w-3xl mx-auto px-4 py-3 flex items-center justify-between">
			<div class="flex items-center gap-4">
				<a href="/" class="text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white">
					← Back
				</a>
				<h1 class="text-xl font-bold text-slate-900 dark:text-white">
					Timeline
				</h1>
			</div>
			<span class="text-sm text-slate-500 dark:text-slate-400">
				{items.length} items
			</span>
		</div>
	</header>

	<!-- Main Content -->
	<main class="max-w-3xl mx-auto px-4 py-4">
		{#if loading}
			<div class="flex items-center justify-center py-20">
				<div class="text-slate-500 dark:text-slate-400">Loading timeline...</div>
			</div>
		{:else if error}
			<div class="bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 p-4 rounded-lg">
				{error}
				<button
					onclick={() => loadTimeline()}
					class="ml-2 underline hover:no-underline"
				>
					Retry
				</button>
			</div>
		{:else}
			<TimelineView {items} {hasMore} onLoadMore={handleLoadMore} />

			{#if loadingMore}
				<div class="text-center py-4 text-slate-500 dark:text-slate-400">
					Loading more...
				</div>
			{/if}
		{/if}
	</main>
</div>
