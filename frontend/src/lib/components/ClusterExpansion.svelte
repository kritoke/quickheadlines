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
				<li>
					<a
						href={item.link}
						target="_blank"
						rel="noopener noreferrer"
						class="flex items-start gap-2 px-3 {spacing.default} hover:opacity-80 transition-opacity"
					>
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
							<h4 class="text-sm theme-text-primary line-clamp-2">
								{item.title}
							</h4>
							<p class="text-xs theme-text-secondary mt-0.5">
								{item.feed_title}
								{#if item.pub_date}
									<span class="mx-1">&middot;</span>
									{formatTimestamp(item.pub_date)}
								{/if}
							</p>
						</div>
					</a>
				</li>
			{/each}
		</ul>
	</div>
{/if}
