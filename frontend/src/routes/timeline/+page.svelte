<script lang="ts">
	import AppHeader from '$lib/components/AppHeader.svelte';
	import LayoutPicker from '$lib/components/LayoutPicker.svelte';
	import BitsSearchModal from '$lib/components/BitsSearchModal.svelte';
	import { fetchTimeline, fetchConfig } from '$lib/api';
	import type { TimelineItemResponse } from '$lib/types';
	import { SvelteSet } from 'svelte/reactivity';
	import {
		createTimelineEffects,
	} from '$lib/stores/effects.svelte';
	import { logger, initDebug, setDebugEnabled } from '$lib/utils/debug';
	import { goto } from '$app/navigation';
	import { themeState } from '$lib/stores/theme.svelte';
	import {
		timelineState,
		loadTimeline,
		loadTimelineConfig,
		handleLoadMore as doLoadMore,
		getFilteredItems,
		isLoading,
		isError,
		getError
	} from '$lib/stores/timelineStore.svelte';

	let LazyTimelineView: any = null;
	const loadTimelineView = async () => {
		if (!LazyTimelineView) {
			const { default: component } = await import('$lib/components/TimelineView.svelte');
			LazyTimelineView = component;
		}
		return LazyTimelineView;
	};

	let LazySearchModal: any = null;
	const loadSearchModal = async () => {
		if (!LazySearchModal) {
			const { default: component } = await import('$lib/components/BitsSearchModal.svelte');
			LazySearchModal = component;
		}
		return LazySearchModal;
	};

	let searchQuery = $state('');
	let searchExpanded = $state(false);
	let timelineEffects: ReturnType<typeof createTimelineEffects> | null = null;
	let sentinelElement: HTMLDivElement | undefined = $state();
	let visibilityHandler: (() => void) | null = null;
	
	let filteredItems = $derived(getFilteredItems(searchQuery));
	
	let loading = $derived(isLoading(timelineState));
	let error = $derived(isError(timelineState) ? getError(timelineState) : null);
	
	$effect(() => {
		if (!sentinelElement || !timelineState.hasMore) return;
		
		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach(entry => {
					if (entry.isIntersecting && !timelineState.loadingMore && timelineState.hasMore) {
						doLoadMore();
					}
				});
			},
			{ rootMargin: '500px' }
		);
		
		observer.observe(sentinelElement);
		
		return () => observer.disconnect();
	});
	
	$effect(() => {
		const initialized = timelineState.status !== 'idle' || timelineState.items.length > 0;
		
		if (!initialized) {
			loadTimeline();
			loadTimelineConfig();
			
			timelineEffects = createTimelineEffects();
			timelineEffects.start();

			visibilityHandler = () => {
			};
			document.addEventListener('visibilitychange', visibilityHandler);
		}
		
		return () => {
			if (timelineEffects) {
				timelineEffects.stop();
			}
			if (visibilityHandler) {
				document.removeEventListener('visibilitychange', visibilityHandler);
				visibilityHandler = null;
			}
		};
	});
	
	async function handleRetry() {
		await loadTimeline();
	}

	function handleLogoClick() {
		window.scrollTo(0, 0);
		goto('/?tab=all');
	}
</script>

<svelte:head>
	<title>Timeline - QuickHeadlines</title>
</svelte:head>

<div class="min-h-screen bg-white dark:bg-slate-900 transition-colors">
	<AppHeader 
		title="QuickHeadlines"
		viewLink={{ href: '/', icon: 'rss' }}
		{searchExpanded}
		onSearchToggle={() => searchExpanded = !searchExpanded}
		onLogoClick={handleLogoClick}
	>
		{#snippet metadata()}
			<span class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 whitespace-nowrap">
				<span class="sm:hidden">{filteredItems.length}</span>
				<span class="hidden sm:inline">{filteredItems.length} items</span>
			</span>
		{/snippet}
		
		{#snippet actions()}
			<LayoutPicker />
		{/snippet}
	</AppHeader>

	{#if searchExpanded}
		{#await loadSearchModal()}
			<div></div>
		{:then SearchModal}
			<SearchModal 
				open={searchExpanded}
				query={searchQuery}
				placeholder="Search timeline..."
				onClose={() => searchExpanded = false}
				onQueryChange={(value: string) => searchQuery = value}
			/>
		{/await}
	{/if}

	<main class="max-w-[1800px] mx-auto px-4 md:px-8 xl:px-12 py-4 overflow-visible" style="padding-top: calc(var(--header-height, 4rem) + 2rem);">
		{#if loading && timelineState.items.length === 0}
			<div class="flex items-center justify-center py-20 gap-3">
				<div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
				<div class="text-slate-500 dark:text-slate-400">Loading timeline...</div>
			</div>
		{:else if error && timelineState.items.length === 0}
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
			{#if loading && timelineState.items.length > 0}
				<div class="sticky top-0 z-20 bg-white/80 dark:bg-slate-900/80 backdrop-blur-sm py-2 flex items-center justify-center gap-2">
					<div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-slate-600 dark:text-slate-400">Refreshing...</span>
				</div>
			{/if}

			{#if timelineState.isClustering}
				<div class="sticky top-12 z-10 bg-amber-50 dark:bg-amber-900/20 py-2 flex items-center justify-center gap-2">
					<div class="w-4 h-4 border-2 border-amber-500 border-t-transparent rounded-full animate-spin"></div>
					<span class="text-sm text-amber-700 dark:text-amber-400">Grouping similar articles...</span>
				</div>
			{/if}

			{#if filteredItems.length > 0}
				{#await loadTimelineView()}
					<div class="flex items-center justify-center py-8">
						<div class="text-slate-500 dark:text-slate-400">Loading timeline view...</div>
					</div>
				{:then TimelineView}
					<TimelineView items={filteredItems} hasMore={timelineState.hasMore} onLoadMore={doLoadMore} />
				{/await}
			{:else if searchQuery}
				<div class="text-center py-20 text-slate-500 dark:text-slate-400">
					No results for "{searchQuery}". Try a different search term.
				</div>
			{/if}

			{#if timelineState.loadingMore}
				<div class="text-center py-4">
					<span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
						<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-slate-500 dark:text-slate-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Loading more...
					</span>
				</div>
			{/if}
			
			{#if timelineState.hasMore}
				<div bind:this={sentinelElement} class="h-1"></div>
			{/if}
		{/if}
	</main>
</div>
