<script lang="ts">
	import type { FeedResponse, ItemResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { themeState, customThemeIds } from '$lib/stores/theme.svelte';
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
	
	let isMobile = $state(false);

	let resolvedTheme = $derived(themeState.theme);
	let isCustomTheme = $derived(customThemeIds.includes(resolvedTheme as any));

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

	<div class="flex-1 min-h-0 px-3 py-2 overflow-y-auto" style="max-height: 320px;">
		<ul class="divide-y divide-slate-200 dark:divide-slate-700/50">
			{#each feed.items as item, i (`${feed.url}-${i}`)}
				<li class="flex items-start gap-2 py-2">
					<a
						href={sanitizeUrl(item.link)}
						target="_blank"
						rel="noopener noreferrer"
						class="flex-1 min-w-0 block hover:opacity-70 transition-opacity"
					>
						<p class="text-sm theme-text-primary line-clamp-2 leading-tight font-medium">
							{item.title}
						</p>
						{#if item.pub_date}
							<p class="text-xs theme-text-secondary mt-0.5">
								{formatTimestamp(item.pub_date)}
							</p>
						{/if}
					</a>
					{#if item.comment_url || item.commentary_url}
						<div class="flex shrink-0 gap-1 mt-0.5">
							{#if item.comment_url}
								<a
									href={sanitizeUrl(item.comment_url)}
									target="_blank"
									rel="noopener noreferrer"
									title="Comments"
									class="p-1 hover:opacity-80 transition-opacity"
								>
									<svg class="w-4 h-4 theme-text-secondary" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
									</svg>
								</a>
							{/if}
							{#if item.commentary_url && item.commentary_url !== item.comment_url}
								<a
									href={sanitizeUrl(item.commentary_url)}
									target="_blank"
									rel="noopener noreferrer"
									title="Discussion"
									class="p-1 hover:opacity-80 transition-opacity"
								>
									<svg class="w-4 h-4 theme-text-secondary" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
									</svg>
								</a>
							{/if}
						</div>
					{/if}
				</li>
			{/each}
		</ul>
	</div>

	{#if feed.has_more}
		<div class="px-3 py-2 border-t border-slate-200 dark:border-slate-700/50">
			<button
				type="button"
				data-name="load-more"
				disabled={loading}
				onclick={() => onLoadMore?.()}
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
					Load more
				{/if}
			</button>
		</div>
	{/if}
</Card>