<script lang="ts">
	import type { FeedResponse, ItemResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { themeState } from '$lib/stores/theme.svelte';

	interface Props {
		feed: FeedResponse;
		onLoadMore?: () => void;
	}

	let { feed, onLoadMore }: Props = $props();

	let scrollContainer: HTMLDivElement | undefined = $state();
	let isScrolledToBottom = $state(false);

	// Reactive header style - properly tracks themeState.theme changes
	let headerStyle = $derived.by(() => {
		const dark = themeState.theme === 'dark';
		const bgColor = feed.header_color || '#64748b';
		const textColor = feed.header_text_color || '#ffffff';
		
		if (feed.header_theme_colors) {
			const colors = dark ? feed.header_theme_colors.dark : feed.header_theme_colors.light;
			if (colors) {
				return `background-color: ${colors.bg}; color: ${colors.text};`;
			}
		}
		
		return `background-color: ${bgColor}; color: ${textColor};`;
	});

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

	function getFaviconSrc(): string {
		if (feed.favicon_data) return feed.favicon_data;
		if (feed.favicon) return feed.favicon;
		return '/favicon.svg';
	}
</script>

<div class="rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-sm overflow-hidden flex flex-col h-[400px]">
	<!-- Feed Header -->
	<a
		href={feed.site_link || '#'}
		target="_blank"
		rel="noopener noreferrer"
		class="flex items-center gap-2 px-3 py-2 font-semibold text-sm hover:opacity-90 transition-opacity"
		style={headerStyle}
	>
		{#if feed.favicon || feed.favicon_data}
			<div class="w-5 h-5 rounded bg-white/90 p-0.5 flex items-center justify-center shadow-sm">
				<img
					src={getFaviconSrc()}
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

	<!-- Feed Items with Scroll Hint -->
	<div class="flex-1 relative">
		<div
			bind:this={scrollContainer}
			class="h-full overflow-y-auto auto-hide-scroll"
		>
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
		</div>

		<!-- Scroll Hint - positioned at bottom of visible area -->
		{#if !isScrolledToBottom && feed.items.length > 5}
			<div class="absolute bottom-0 left-0 right-0 h-6 pointer-events-none bg-gradient-to-t from-white dark:from-slate-800 via-white/80 dark:via-slate-800/80 to-transparent"></div>
		{/if}
	</div>

	<!-- Load More -->
	{#if feed.total_item_count > feed.items.length}
		<div class="p-2 border-t border-slate-200 dark:border-slate-700">
			<button
				onclick={onLoadMore}
				class="w-full text-xs text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 py-1 transition-colors"
			>
				+{feed.total_item_count - feed.items.length} more
			</button>
		</div>
	{/if}
</div>
