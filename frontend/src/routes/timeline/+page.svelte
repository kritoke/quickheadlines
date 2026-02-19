<script lang="ts">
	import TimelineView from '$lib/components/TimelineView.svelte';
	import { fetchTimeline, fetchConfig } from '$lib/api';
	import type { TimelineItemResponse } from '$lib/types';
	import { themeState, toggleCoolMode } from '$lib/stores/theme.svelte';
	import { onMount } from 'svelte';
	import { SvelteSet } from 'svelte/reactivity';
	import AnimatedThemeToggler from '$lib/components/AnimatedThemeToggler.svelte';

	let items = $state<TimelineItemResponse[]>([]);
	let itemIds = $state(new SvelteSet<string>());
	let hasMore = $state(false);
	let loading = $state(true);
	let loadingMore = $state(false);
	let error = $state<string | null>(null);
	let offset = $state(0);
	let sentinelElement: HTMLDivElement | undefined = $state();
	const limit = 100;
	
	let refreshInterval: ReturnType<typeof setInterval>;
	let refreshMinutes = $state(10);
	
	async function loadConfig() {
		try {
			const config = await fetchConfig();
			const newRefreshMinutes = config.refresh_minutes || 10;
			
			if (refreshInterval && newRefreshMinutes !== refreshMinutes) {
				clearInterval(refreshInterval);
				refreshInterval = setInterval(() => {
					loadTimeline();
				}, newRefreshMinutes * 60 * 1000);
			}
			
			refreshMinutes = newRefreshMinutes;
		} catch (e) {
			console.warn('Failed to fetch config:', e);
		}
	}

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
				const newItems = response.items.filter((item: TimelineItemResponse) => !itemIds.has(item.id));
				newItems.forEach((item: TimelineItemResponse) => itemIds.add(item.id));
				items = [...items, ...newItems];
			} else {
				itemIds = new SvelteSet(response.items.map((item: TimelineItemResponse) => item.id));
				items = response.items;
			}
			
			hasMore = response.has_more;
			offset += response.items.length;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load timeline';
			console.error('[Timeline] Error:', e);
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

	$effect(() => {
		if (!sentinelElement || !hasMore) return;
		
		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach(entry => {
					if (entry.isIntersecting && !loadingMore && hasMore) {
						handleLoadMore();
					}
				});
			},
			{ rootMargin: '500px' }
		);
		
		observer.observe(sentinelElement);
		
		return () => observer.disconnect();
	});

	onMount(() => {
		loadTimeline();
		loadConfig();
		
		refreshInterval = setInterval(() => {
			loadTimeline();
		}, refreshMinutes * 60 * 1000);
		
		return () => {
			if (refreshInterval) clearInterval(refreshInterval);
		};
	});
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors">
	<header class="fixed top-0 left-0 right-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20">
		<div class="max-w-7xl mx-auto px-2 sm:px-4 py-2 sm:py-3 flex items-center justify-between">
			<div class="flex items-center gap-2 sm:gap-3 min-w-0">
				<a href="/" class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0">
					<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
					<span class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">Timeline</span>
				</a>
				<span class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 hidden sm:block whitespace-nowrap">
					{items.length} items
				</span>
			</div>
			<div class="flex items-center gap-1 sm:gap-2">
				<a 
					href="/" 
					class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Feed view"
					title="Feeds"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path d="M4 11a9 9 0 0 1 9 9" />
						<path d="M4 4a16 16 0 0 1 16 16" />
						<circle cx="5" cy="19" r="1" fill="currentColor" />
					</svg>
				</a>
				<button
					onclick={toggleCoolMode}
					class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Toggle cool mode"
					title="Particle effects"
				>
					<svg 
						class="w-5 h-5"
						class:text-pink-500={themeState.coolMode}
						class:text-slate-400={!themeState.coolMode}
						class:dark:text-slate-500={!themeState.coolMode}
						viewBox="0 0 24 24" 
						fill="currentColor"
					>
						<circle cx="5" cy="5" r="2.5" />
						<circle cx="12" cy="8" r="2" />
						<circle cx="19" cy="5" r="2.5" />
						<circle cx="7" cy="12" r="1.5" />
						<circle cx="17" cy="12" r="1.5" />
						<circle cx="5" cy="19" r="2.5" />
						<circle cx="12" cy="16" r="2" />
						<circle cx="19" cy="19" r="2.5" />
					</svg>
				</button>
				<AnimatedThemeToggler class="p-1.5 sm:p-2" title="Toggle theme" />
			</div>
		</div>
	</header>

	<main class="max-w-7xl mx-auto px-2 sm:px-4 py-4 pt-20 sm:pt-20">
		{#if loading && items.length === 0}
			<div class="flex items-center justify-center py-20">
				<div class="text-slate-500 dark:text-slate-400">Loading timeline...</div>
			</div>
		{:else if error && items.length === 0}
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
			
			{#if hasMore}
				<div bind:this={sentinelElement} class="h-1"></div>
			{/if}
		{/if}
	</main>
</div>
