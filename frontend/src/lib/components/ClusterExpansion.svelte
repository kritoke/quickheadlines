<script lang="ts">
	import type { StoryResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';
	import { getFaviconSrc } from '$lib/utils/feedItem';
	import { spacing } from '$lib/design/tokens';

	interface Props {
		items: StoryResponse[];
		loading?: boolean;
	}

	let { items, loading = false }: Props = $props();
</script>

{#if loading}
	<div class="{spacing.default} px-3 text-center text-slate-500 dark:text-slate-400 text-sm">
		Loading similar stories...
	</div>
{:else if items.length > 0}
	<div class="cluster-expansion border-t border-slate-200 dark:border-slate-700" data-name="cluster-expansion">
		<div class="{spacing.default} px-3 bg-slate-50 dark:bg-slate-800/50">
			<span class="text-xs font-medium text-slate-600 dark:text-slate-400">
				Similar stories ({items.length})
			</span>
		</div>
		<ul class="divide-y divide-slate-100 dark:divide-slate-700">
			{#each items as item, i (`cluster-item-${item.id}-${i}`)}
				<li class="flex items-start gap-2 px-3 {spacing.default}">
					<div class="w-4 h-4 rounded theme-bg-secondary p-0.5 flex items-center justify-center shadow-sm flex-shrink-0 mt-0.5">
						<img
							src={getFaviconSrc(item)}
							alt="{item.feed_title} favicon"
							class="w-3 h-3 rounded"
							onerror={(e) => {
								const target = e.target as HTMLImageElement;
								target.src = '/favicon.svg';
							}}
						/>
					</div>
					<div class="flex-1 min-w-0">
						<a
							href={item.link}
							target="_blank"
							rel="noopener noreferrer"
							class="text-sm theme-text-primary line-clamp-2 hover:opacity-80 transition-opacity block"
						>
							{item.title}
						</a>
						<p class="text-xs theme-text-secondary mt-0.5 flex items-center gap-1">
							<span>{item.feed_title}</span>
							{#if item.pub_date}
								<span class="mx-1">&middot;</span>
								{formatTimestamp(item.pub_date)}
							{/if}
						</p>
					</div>
					<div class="flex shrink-0 gap-1 mt-0.5">
						{#if item.comment_url}
							<a
								href={item.comment_url}
								target="_blank"
								rel="noopener noreferrer"
								title="Comments"
								class="p-0.5"
							>
								<svg class="w-3.5 h-3.5 theme-text-secondary hover:theme-text-primary" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
								</svg>
							</a>
						{/if}
						{#if item.commentary_url && item.commentary_url !== item.comment_url}
							<a
								href={item.commentary_url}
								target="_blank"
								rel="noopener noreferrer"
								title="Discussion"
								class="p-0.5"
							>
								<svg class="w-3.5 h-3.5 theme-text-secondary hover:theme-text-primary" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
								</svg>
							</a>
						{/if}
					</div>
				</li>
			{/each}
		</ul>
	</div>
{/if}
