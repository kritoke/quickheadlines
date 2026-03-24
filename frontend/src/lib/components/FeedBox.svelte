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
	import { spacing } from '$lib/design/tokens';
	import { sanitizeUrl, sanitizeCssColor } from '$lib/utils/validation';

	interface Props {
		feed: FeedResponse;
		onLoadMore?: () => void;
		loading?: boolean;
	}

	let { feed, onLoadMore, loading = false }: Props = $props();
	
	let expanded = $state(false);
	let scrollContainer: HTMLDivElement | undefined = $state();
	let isScrolledToBottom = $state(false);
	let isMobile = $state(false);

	let resolvedTheme = $derived(themeState.theme);

	let cardHasShadow = $derived(themeState.effects);
	let isCustomTheme = $derived(customThemeIds.includes(resolvedTheme as any));

	const INITIAL_ITEMS = 15;
	const MOBILE_INITIAL_ITEMS = 10;

	// Mobile shows 10 items with expand toggle, desktop uses scroll with initial limit
	let displayedItems = $derived((isMobile && !expanded) ? feed.items.slice(0, MOBILE_INITIAL_ITEMS) : (expanded ? feed.items : feed.items.slice(0, INITIAL_ITEMS)));
	let hasMore = $derived((isMobile && !expanded && feed.items.length > MOBILE_INITIAL_ITEMS) || (!isMobile && !expanded && feed.items.length > INITIAL_ITEMS));
	
	// Memoized favicon source for this feed
	let faviconSrc = $derived(getFaviconSrc({ 
		favicon: feed.favicon, 
		favicon_data: feed.favicon_data, 
		url: feed.url 
	}));

	function getHeaderStyle(): string {
		const dark = resolvedTheme === 'dark';
		const bgColor = sanitizeCssColor(feed.header_color || '#64748b', '#64748b');
		const textColor = sanitizeCssColor(feed.header_text_color || '#ffffff', '#ffffff');
		
		if (feed.header_theme_colors) {
			const colors = dark ? feed.header_theme_colors.dark : feed.header_theme_colors.light;
			if (colors) {
				return `background-color: ${sanitizeCssColor(colors.bg, '#64748b')}; color: ${sanitizeCssColor(colors.text, '#ffffff')};`;
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

	$effect(() => {
		const container = scrollContainer;
		if (!container) return;
		
		container.addEventListener('scroll', checkScrollPosition);
		checkScrollPosition();
		
		return () => {
			container.removeEventListener('scroll', checkScrollPosition);
		};
	});

	// Detect mobile viewport
	$effect(() => {
		isMobile = window.innerWidth < 768 || 'ontouchstart' in window;
		
		const handleResize = () => {
			isMobile = window.innerWidth < 768 || 'ontouchstart' in window;
		};
		
		window.addEventListener('resize', handleResize);
		return () => window.removeEventListener('resize', handleResize);
	});
</script>

<Card 
	class="overflow-hidden flex flex-col {isMobile ? 'h-auto min-h-[200px]' : 'h-[400px]'} transform-gpu relative"
	themeVariant={isCustomTheme}
	data-name="feed-box"
>
	<!-- Feed Header -->
	<a
		href={sanitizeUrl(feed.site_link || '#')}
		target="_blank"
		rel="noopener noreferrer"
		class="flex items-center gap-2 p-3 font-semibold text-sm hover:opacity-90 transition-opacity"
		style={getHeaderStyle()}
	>
	{#if feed.favicon || feed.favicon_data || faviconSrc}
		<div class="w-5 h-5 rounded bg-white/90 dark:bg-white/80 p-0.5 flex items-center justify-center shadow-sm border border-white/20">
			<img
				src={faviconSrc}
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
	<div class="flex-1 relative {isMobile ? 'overflow-visible' : 'min-h-0'}">
		{#if !isMobile}
		<CustomScrollbar bind:scrollContainer onScroll={checkScrollPosition} class="absolute inset-0">
			<ul class="divide-y theme-border/30">
				{#each displayedItems as item, i (`${feed.url}-${i}`)}
					<li>
						<a
							href={sanitizeUrl(item.link)}
							target="_blank"
							rel="noopener noreferrer"
							class="block p-3 hover:opacity-80 transition-opacity"
						>
							<p class="text-base theme-text-primary line-clamp-2 leading-snug">
								{item.title}
							</p>
							{#if item.pub_date}
								<p class="text-sm theme-text-secondary mt-2">
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
			<div class="absolute bottom-0 left-0 right-0 h-6 pointer-events-none bg-gradient-to-t theme-bg-primary/80 to-transparent"></div>
		{/if}
		{:else}
		<!-- Mobile: Show items with expand toggle -->
		<ul class="divide-y theme-border/30">
			{#each displayedItems as item, i (`${feed.url}-${i}`)}
				<li>
					<a
						href={sanitizeUrl(item.link)}
						target="_blank"
						rel="noopener noreferrer"
						class="block p-3 hover:opacity-80 transition-opacity"
					>
						<p class="text-base theme-text-primary line-clamp-2 leading-snug">
							{item.title}
						</p>
						{#if item.pub_date}
							<p class="text-sm theme-text-secondary mt-2">
								{formatTimestamp(item.pub_date)}
							</p>
						{/if}
					</a>
				</li>
			{/each}
		</ul>
		{/if}
	</div>

	<!-- Load More (both mobile and desktop) -->
	{#if hasMore}
		<div class="{spacing.default} border-t theme-border">
			<button
				type="button"
				data-name="load-more"
				disabled={loading}
				onclick={handleLoadMore}
				class="w-full py-3 text-sm font-medium theme-text-secondary hover:theme-text-primary {spacing.default} transition-all duration-200 disabled:opacity-50 active:scale-95"
			>
				{#if loading}
					<span class="inline-flex items-center gap-1">
						<svg class="animate-spin h-3 w-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Loading...
					</span>
				{:else if isMobile}
					Show more ({feed.items.length - MOBILE_INITIAL_ITEMS} more)
				{:else}
					Show more
				{/if}
			</button>
		</div>
	{/if}
</Card>
