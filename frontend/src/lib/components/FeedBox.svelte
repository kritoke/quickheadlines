<script lang="ts">
	import type { FeedResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { readModeState } from '$lib/stores/readMode.svelte';
	import { breakpointState } from '$lib/utils/breakpoint.svelte';
	import { getFaviconSrc, getHeaderStyle as getSharedHeaderStyle, getFaviconBgStyle as getSharedFaviconBgStyle } from '$lib/utils/feedItem';
	import { feedState } from '$lib/stores/feedStore.svelte';
	import { sanitizeUrl } from '$lib/utils/validation';
	import CommentIcon from './icons/CommentIcon.svelte';
	import DiscussionIcon from './icons/DiscussionIcon.svelte';
	import { goto } from '$app/navigation';
	import { cn } from '$lib/utils';

	interface Props {
		feed: FeedResponse;
		onLoadMore?: () => void;
		loading?: boolean;
	}

	let { feed, onLoadMore, loading = false }: Props = $props();

	let isMobile = $derived(breakpointState.isMobile);

	let faviconSrc = $derived(getFaviconSrc({ 
		favicon: feed.favicon, 
		favicon_data: feed.favicon_data
	}));

	let isDark = $derived(document.documentElement.classList.contains('dark'));
	let headerStyle = $derived(getSharedHeaderStyle(feed, isDark));
	let faviconBgStyle = $derived(getSharedFaviconBgStyle(feed, isDark));

	let feedLoading = $derived(feedState.status === 'loading' || feedState.status === 'refreshing');
</script>

<div 
	class={cn('rounded-2xl border border-surface-200 dark:border-surface-700 transition-shadow duration-200 overflow-hidden flex flex-col group', 'bg-surface-50 dark:bg-surface-950')}
	data-name="feed-box"
>
	<a
		href={sanitizeUrl(feed.site_link || '#')}
		target="_blank"
		rel="noopener noreferrer"
		class="flex items-center gap-2 px-3 py-2 font-semibold text-sm hover:opacity-90 transition-opacity"
		style={headerStyle}
	>
		{#if feed.favicon || feed.favicon_data || faviconSrc}
			<div class="w-5 h-5 rounded p-0.5 flex items-center justify-center shadow-sm shrink-0" style={faviconBgStyle}>
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

	<div class="flex-1 min-h-0 px-3 py-2 feed-box-scroll" class:overflow-y-auto={!isMobile} class:overflow-y-visible={isMobile} style={!isMobile ? 'max-height: 320px' : ''}>
		<ul class="divide-y divide-slate-200 dark:divide-slate-700/50">
			{#each feed.items as item, i (`${feed.url}-${i}`)}
				<li class="flex items-start gap-2 py-2">
					{#if readModeState.mode === 'read'}
						<button
							type="button"
							onclick={() => goto(`/reader?url=${encodeURIComponent(item.link)}&title=${encodeURIComponent(item.title)}`)}
							class="flex-1 min-w-0 block text-left hover:opacity-70 transition-opacity"
						>
							<p class="text-sm text-surface-950 dark:text-surface-50 line-clamp-2 leading-tight font-medium">
								{item.title}
							</p>
							{#if item.pub_date}
								<p class="text-xs text-surface-700 dark:text-surface-300 mt-0.5">
									{formatTimestamp(item.pub_date)}
								</p>
							{/if}
						</button>
					{:else}
					<a
						href={sanitizeUrl(item.link)}
						target="_blank"
						rel="noopener noreferrer"
						class="flex-1 min-w-0 block hover:opacity-70 transition-opacity"
					>
						<p class="text-sm text-surface-950 dark:text-surface-50 line-clamp-2 leading-tight font-medium">
							{item.title}
						</p>
						{#if item.pub_date}
							<p class="text-xs text-surface-700 dark:text-surface-300 mt-0.5">
								{formatTimestamp(item.pub_date)}
							</p>
						{/if}
					</a>
					{/if}
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
									<CommentIcon class="w-4 h-4 text-surface-700 dark:text-surface-300" />
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
									<DiscussionIcon class="w-4 h-4 text-surface-700 dark:text-surface-300" />
								</a>
							{/if}
						</div>
					{/if}
				</li>
			{:else}
				<li class="py-6 text-center">
					{#if feedLoading}
						<div class="flex items-center justify-center gap-2">
							<div class="w-3 h-3 border-2 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
							<span class="text-sm text-surface-700 dark:text-surface-300">Loading...</span>
						</div>
					{:else}
						<span class="text-sm text-surface-700 dark:text-surface-300">No items</span>
					{/if}
				</li>
			{/each}
		</ul>
	</div>

	<div class="px-3 py-2 border-t border-slate-200 dark:border-slate-700/50">
		{#if feed.items.length > 5 && feed.total_item_count > feed.items.length}
			<button
				type="button"
				data-name="load-more"
				disabled={loading}
				onclick={() => {
					onLoadMore?.();
				}}
				class="w-full py-2 text-sm font-medium text-surface-700 dark:text-surface-300 hover:text-surface-950 dark:text-surface-50 transition-colors disabled:opacity-50"
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
					Load {feed.total_item_count - feed.items.length} more items
				{/if}
			</button>
		{:else if feed.items.length > 0 && feed.items.length >= feed.total_item_count}
			<div class="py-2 text-center">
				<span class="text-sm text-surface-700 dark:text-surface-300">No more items</span>
			</div>
		{:else}
			<div class="py-2"></div>
		{/if}
	</div>
</div>
