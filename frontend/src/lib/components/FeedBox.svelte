<script lang="ts">
	import type { FeedResponse, ItemResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { themeState, customThemeIds } from '$lib/stores/theme.svelte';
	import { slide } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';
	import { getFaviconSrc } from '$lib/utils/feedItem';
	import ScrollToTop from './ScrollToTop.svelte';
	import CustomScrollbar from './CustomScrollbar.svelte';
	import Card from './ui/Card.svelte';

	interface Props {
		feed: FeedResponse;
		onLoadMore?: () => void;
		loading?: boolean;
	}

	let { feed, onLoadMore, loading = false }: Props = $props();
	
	let scrollContainer: HTMLDivElement | undefined = $state();
	let isScrolledToBottom = $state(false);

	let resolvedTheme = $derived(themeState.theme);

	let cardHasShadow = $derived(themeState.effects);
	let isCustomTheme = $derived(customThemeIds.includes(resolvedTheme as any));

	function getHeaderStyle(): string {
		const dark = resolvedTheme === 'dark';
		const bgColor = feed.header_color || '#64748b';
		const textColor = feed.header_text_color || '#ffffff';
		
		if (feed.header_theme_colors) {
			const colors = dark ? feed.header_theme_colors.dark : feed.header_theme_colors.light;
			if (colors) {
				return `background-color: ${colors.bg}; color: ${colors.text};`;
			}
		}
		
		return `background-color: ${bgColor}; color: ${textColor};`;
	}

	function checkScrollPosition() {
		if (!scrollContainer) return;
		
		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		const maxScroll = scrollHeight - clientHeight;
		
		isScrolledToBottom = maxScroll > 0 && scrollTop >= maxScroll - 10;
	}
</script>

<Card 
	class="overflow-hidden flex flex-col h-[500px] relative hover-glow" 
	themeVariant={isCustomTheme}
	data-name="feed-box"
>
	<!-- Feed Header -->
	<a
		href={feed.site_link || '#'}
		target="_blank"
		rel="noopener noreferrer"
		class="flex items-center gap-2 px-3 py-2 font-semibold text-sm hover:opacity-90 transition-opacity"
		style={getHeaderStyle()}
	>
		{#if feed.favicon || feed.favicon_data || getFaviconSrc(feed)}
			<div class="w-5 h-5 rounded bg-white/90 p-0.5 flex items-center justify-center shadow-sm">
				<img
					src={getFaviconSrc(feed)}
					alt="{feed.title} favicon"
					class="w-4 h-4 rounded"
					onerror={(e) => {
						const target = e.target as HTMLImageElement;
						target.src = '/favicon.svg';
					}}
				/>
			</div>
		{/if}
		<span class="truncate drop-shadow-sm">{feed.title}</span>
	</a>

	<!-- Feed Items with Scroll -->
	<div class="flex-1 relative min-h-0">
		<CustomScrollbar bind:scrollContainer onScroll={checkScrollPosition} class="absolute inset-0">
			<ul class="divide-y divide-slate-100 dark:divide-slate-700">
				{#each feed.items as item, i (`${feed.url}-${i}`)}
					<li>
						<a
							href={item.link}
							target="_blank"
							rel="noopener noreferrer"
							class="block px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
						>
							<p class="text-sm text-slate-800 dark:text-slate-200 line-clamp-2 leading-snug">
								{item.title}
							</p>
							{#if item.pub_date}
								<p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
									{formatTimestamp(item.pub_date)}
								</p>
							{/if}
						</a>
					</li>
				{/each}
			</ul>
		</CustomScrollbar>

		<!-- Scroll Hint - positioned at bottom of visible area -->
		{#if !isScrolledToBottom && feed.items.length > 5}
			<div class="absolute bottom-0 left-0 right-0 h-6 pointer-events-none bg-gradient-to-t from-white dark:from-slate-800 via-white/80 dark:via-slate-800/80 to-transparent"></div>
		{/if}
	</div>

	<!-- Load More -->
	{#if feed.total_item_count > feed.items.length}
		<div class="p-2 border-t border-slate-200 dark:border-slate-700">
			<button
				type="button"
				data-name="load-more"
				disabled={loading}
				onclick={onLoadMore}
				class="w-full text-xs text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 py-1 transition-all duration-200 disabled:opacity-50 active:scale-95"
			>
				{#if loading}
					<span class="inline-flex items-center gap-1">
						<svg class="animate-spin h-3 w-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Loading...
					</span>
				{:else}
					+{feed.total_item_count - feed.items.length} more
				{/if}
			</button>
		</div>
	{/if}
</Card>
