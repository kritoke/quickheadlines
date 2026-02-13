<script lang="ts">
	import type { FeedResponse, ItemResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { onMount } from 'svelte';
	import { cn } from '$lib/utils';
	import { isDark } from '$lib/stores/theme.svelte';

	interface Props {
		feed: FeedResponse;
		onLoadMore?: () => void;
	}

	let { feed, onLoadMore }: Props = $props();

	let scrollContainer: HTMLDivElement | undefined = $state();
	let isScrolledToBottom = $state(false);

	function getHeaderStyle(): string {
		const dark = isDark();
		
		if (feed.header_theme_colors) {
			const colors = dark ? feed.header_theme_colors.dark : feed.header_theme_colors.light;
			if (colors) {
				return `background-color: ${colors.bg}; color: ${colors.text};`;
			}
		}
		
		if (feed.header_color && feed.header_text_color) {
			return `background-color: ${feed.header_color}; color: ${feed.header_text_color};`;
		}
		
		return '';
	}

	let headerStyle = $derived(getHeaderStyle());

	function checkScrollPosition() {
		if (!scrollContainer) return;
		
		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		const maxScroll = scrollHeight - clientHeight;
		
		isScrolledToBottom = maxScroll > 0 && scrollTop >= maxScroll - 10;
	}

	onMount(() => {
		if (scrollContainer) {
			scrollContainer.addEventListener('scroll', checkScrollPosition);
			checkScrollPosition();
		}
		
		return () => {
			if (scrollContainer) {
				scrollContainer.removeEventListener('scroll', checkScrollPosition);
			}
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
			<img
				src={getFaviconSrc()}
				alt="{feed.title} favicon"
				class="w-5 h-5 rounded"
				onerror={(e) => {
					const target = e.target as HTMLImageElement;
					target.src = '/favicon.svg';
				}}
			/>
		{/if}
		<span class="truncate">{feed.title}</span>
	</a>

	<!-- Feed Items -->
	<div
		bind:this={scrollContainer}
		class="flex-1 overflow-y-auto auto-hide-scroll relative"
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

		<!-- Scroll Hint -->
		{#if !isScrolledToBottom}
			<div class="absolute bottom-0 left-0 right-0 h-8 bg-gradient-to-t from-white dark:from-slate-800 to-transparent pointer-events-none"></div>
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
