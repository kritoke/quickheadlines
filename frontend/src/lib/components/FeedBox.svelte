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
	
	let expanded = $state(false);
	let scrollContainer: HTMLDivElement | undefined = $state();
	let isScrolledToBottom = $state(false);

	let resolvedTheme = $derived(themeState.theme);

	let cardHasShadow = $derived(themeState.effects);
	let isCustomTheme = $derived(customThemeIds.includes(resolvedTheme as any));

	const INITIAL_ITEMS = 15;

	let displayedItems = $derived(expanded ? feed.items : feed.items.slice(0, INITIAL_ITEMS));
	let hasMore = $derived(!expanded && feed.items.length > INITIAL_ITEMS);

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

	function handleLoadMore() {
		expanded = true;
		onLoadMore?.();
	}

	function checkScrollPosition() {
		if (!scrollContainer) return;
		
		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		const maxScroll = scrollHeight - clientHeight;
		
		isScrolledToBottom = maxScroll > 0 && scrollTop >= maxScroll - 10;
	}
</script>

<Card 
	class="overflow-hidden flex flex-col relative hover-glow {expanded ? 'h-auto' : 'h-[500px]'} max-sm:h-auto max-sm:mb-2"
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
			<div class="w-5 h-5 rounded theme-bg-secondary p-0.5 flex items-center justify-center shadow-sm">
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

	<!-- Feed Items -->
	<div class="flex-1 relative min-h-0 max-sm:max-h-none">
		<!-- Mobile: no scrollbar, auto expand -->
		<div class="max-sm:overflow-visible overflow-auto h-full">
			<ul class="divide-y theme-border/30">
				{#each displayedItems as item, i (`${feed.url}-${i}`)}
					<li>
						<a
							href={item.link}
							target="_blank"
							rel="noopener noreferrer"
							class="block px-3 py-2 hover:opacity-80 transition-opacity"
						>
							<p class="text-sm theme-text-primary line-clamp-2 leading-snug">
								{item.title}
							</p>
							{#if item.pub_date}
								<p class="text-xs theme-text-secondary mt-1">
									{formatTimestamp(item.pub_date)}
								</p>
							{/if}
						</a>
					</li>
				{/each}
			</ul>
		</div>

		<!-- Scroll Hint - only show on desktop when not expanded -->
		{#if !expanded && !isScrolledToBottom && feed.items.length > 5}
			<div class="absolute bottom-0 left-0 right-0 h-6 pointer-events-none bg-gradient-to-t theme-bg-primary/80 to-transparent"></div>
		{/if}
	</div>

	<!-- Load More / Show Less -->
	{#if feed.items.length > INITIAL_ITEMS}
		<div class="p-2 border-t theme-border">
			<button
				type="button"
				data-name="load-more"
				disabled={loading}
				onclick={handleLoadMore}
				class="w-full text-xs theme-text-secondary hover:theme-text-primary py-1 transition-all duration-200 disabled:opacity-50 active:scale-95"
			>
				{#if loading}
					<span class="inline-flex items-center gap-1">
						<svg class="animate-spin h-3 w-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Loading...
					</span>
				{:else if expanded}
					Show less
				{:else}
					+{feed.items.length - INITIAL_ITEMS} more
				{/if}
			</button>
		</div>
	{/if}
</Card>
