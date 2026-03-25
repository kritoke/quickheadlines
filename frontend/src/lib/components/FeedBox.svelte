<script lang="ts">
	import type { FeedResponse, ItemResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { themeState, customThemeIds } from '$lib/stores/theme.svelte';
	import { slide } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';
	import { getFaviconSrc } from '$lib/utils/feedItem';
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
	let isMobile = $state(false);

	let resolvedTheme = $derived(themeState.theme);
	let isCustomTheme = $derived(customThemeIds.includes(resolvedTheme as any));

	const INITIAL_ITEMS = 10;

	let displayedItems = $derived(
		!expanded 
			? feed.items.slice(0, INITIAL_ITEMS) 
			: feed.items
	);
	
	let hasMore = $derived(
		!expanded && feed.items.length > INITIAL_ITEMS
	);
	
	let faviconSrc = $derived(getFaviconSrc({ 
		favicon: feed.favicon, 
		favicon_data: feed.favicon_data
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

	$effect(() => {
		if (typeof window === 'undefined') return;
		
		const checkMobile = () => {
			isMobile = window.innerWidth < 768 || 'ontouchstart' in window;
		};
		
		checkMobile();
		window.addEventListener('resize', checkMobile);
		
		return () => window.removeEventListener('resize', checkMobile);
	});
</script>

<Card 
	class="overflow-hidden flex flex-col"
	themeVariant={isCustomTheme}
	data-name="feed-box"
>
	<a
		href={sanitizeUrl(feed.site_link || '#')}
		target="_blank"
		rel="noopener noreferrer"
		class="flex items-center gap-2 px-3 py-2 font-semibold text-sm hover:opacity-90 transition-opacity"
		style={getHeaderStyle()}
	>
		{#if feed.favicon || feed.favicon_data || faviconSrc}
			<div class="w-5 h-5 rounded bg-white/90 dark:bg-white/80 p-0.5 flex items-center justify-center shadow-sm border border-white/20 shrink-0">
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

	<div class="flex-1 min-h-0 px-3 py-2">
		<ul class="divide-y divide-slate-200 dark:divide-slate-700/50">
			{#each displayedItems as item, i (`${feed.url}-${i}`)}
				<li>
					<a
						href={sanitizeUrl(item.link)}
						target="_blank"
						rel="noopener noreferrer"
						class="block py-2.5 hover:opacity-70 transition-opacity"
					>
						<p class="text-sm theme-text-primary line-clamp-2 leading-snug font-medium">
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

	{#if hasMore}
		<div class="px-3 py-2 border-t border-slate-200 dark:border-slate-700/50">
			<button
				type="button"
				data-name="load-more"
				disabled={loading}
				onclick={handleLoadMore}
				class="w-full py-2 text-sm font-medium theme-text-secondary hover:theme-text-primary transition-colors disabled:opacity-50"
			>
				{#if loading}
					<span class="inline-flex items-center gap-2">
						<svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						<span>Loading...</span>
					</span>
				{:else}
					Show {feed.items.length - INITIAL_ITEMS} more items
				{/if}
			</button>
		</div>
	{/if}
</Card>