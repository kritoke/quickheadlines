<script lang="ts">
	import TimelineView from '$lib/components/TimelineView.svelte';
	import { fetchTimeline } from '$lib/api';
	import type { TimelineItemResponse } from '$lib/types';
	import { themeState, toggleTheme } from '$lib/stores/theme.svelte';

	let items = $state<TimelineItemResponse[]>([]);
	let itemIds = $state<Set<string>>(new Set());
	let hasMore = $state(false);
	let loading = $state(true);
	let loadingMore = $state(false);
	let error = $state<string | null>(null);
	let offset = $state(0);
	const limit = 100;

	async function loadTimeline(append: boolean = false) {
		console.log('[Timeline] loadTimeline called, append:', append);
		try {
			if (append) {
				loadingMore = true;
			} else {
				loading = true;
			}
			error = null;
			
			const response = await fetchTimeline(limit, offset);
			console.log('[Timeline] Got response, items:', response.items?.length);
			
			if (append) {
				const newItems = response.items.filter((item: TimelineItemResponse) => !itemIds.has(item.id));
				newItems.forEach((item: TimelineItemResponse) => itemIds.add(item.id));
				items = [...items, ...newItems];
			} else {
				itemIds = new Set(response.items.map((item: TimelineItemResponse) => item.id));
				items = response.items;
			}
			
			hasMore = response.has_more;
			offset += response.items.length;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load timeline';
			console.error('[Timeline] Failed to load timeline:', e);
		} finally {
			loading = false;
			loadingMore = false;
		}
	}

	async function handleLoadMore() {
		if (!loadingMore && hasMore) {
			await loadTimeline(true);
		}
	}

	function handleScroll() {
		if (loadingMore || !hasMore) return;
		
		const scrollHeight = document.documentElement.scrollHeight;
		const scrollTop = document.documentElement.scrollTop;
		const clientHeight = document.documentElement.clientHeight;
		
		if (scrollTop + clientHeight >= scrollHeight - 500) {
			handleLoadMore();
		}
	}

	$effect(() => {
		console.log('[Timeline] $effect running, loading timeline...');
		loadTimeline();
		
		window.addEventListener('scroll', handleScroll);
		return () => window.removeEventListener('scroll', handleScroll);
	});
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors">
	<!-- Header -->
	<header class="sticky top-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20">
		<div class="max-w-3xl mx-auto px-4 py-3 flex items-center justify-between">
			<div class="flex items-center gap-4">
				<a href="/" class="text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors">
					← Back
				</a>
				<h1 class="text-xl font-bold text-slate-900 dark:text-white">
					Timeline
				</h1>
			</div>
			<div class="flex items-center gap-4">
				<span class="text-sm text-slate-500 dark:text-slate-400">
					{items.length} items
				</span>
				<button
					onclick={toggleTheme}
					class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Toggle theme"
				>
					{#if themeState.theme === 'dark'}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-yellow-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
						</svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
						</svg>
					{/if}
				</button>
			</div>
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
