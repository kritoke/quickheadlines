<script lang="ts">
	import type { StoryResponse } from '$lib/types';
	import { formatTimestamp } from '$lib/api';

	interface Props {
		items: StoryResponse[];
		loading?: boolean;
	}

	let { items, loading = false }: Props = $props();

	function getFaviconSrc(item: StoryResponse): string {
		if (item.favicon_data) {
			if (item.favicon_data.startsWith('internal:')) {
				const iconName = item.favicon_data.replace('internal:', '');
				if (iconName === 'code_icon') return '/code_icon.svg';
				return '/favicon.svg';
			}
			return item.favicon_data;
		}
		if (item.favicon) {
			if (item.favicon.startsWith('internal:')) return '/favicon.svg';
			return item.favicon;
		}
		return '/favicon.svg';
	}
</script>

{#if loading}
	<div class="py-3 px-3 text-center text-slate-500 dark:text-slate-400 text-sm">
		Loading similar stories...
	</div>
{:else if items.length > 0}
	<div class="cluster-expansion border-t border-slate-200 dark:border-slate-700">
		<div class="py-2 px-3 bg-slate-50 dark:bg-slate-800/50">
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
						class="flex items-start gap-2 px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
					>
						<div class="w-4 h-4 rounded bg-white/90 dark:bg-slate-700 p-0.5 flex items-center justify-center shadow-sm flex-shrink-0 mt-0.5">
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
							<h4 class="text-sm text-slate-800 dark:text-slate-200 line-clamp-2">
								{item.title}
							</h4>
							<p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
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
