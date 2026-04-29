<script lang="ts">
	import { Menu, Portal } from '@skeletonlabs/skeleton-svelte';
	import { layoutState, setTimelineColumns, setFeedColumns, columnOptions, type ColumnCount } from '$lib/stores/layout.svelte';
	import { breakpointState } from '$lib/utils/breakpoint.svelte';

	let isMobile = $derived(breakpointState.isMobile);

	function getColumnBlocks(count: number): string {
		if (count === 1) return 'grid-cols-1';
		if (count === 2) return 'grid-cols-2';
		return 'grid-cols-3';
	}

	interface ColumnOptionData {
		id: ColumnCount;
		name: string;
		singleColumnPreview?: boolean;
	}

	const timelineColumnOptions: ColumnOptionData[] = [
		{ id: 1, name: '1 Column', singleColumnPreview: true },
		...columnOptions.map(o => ({ ...o, singleColumnPreview: o.id === 1 }))
	];
</script>

{#if !isMobile}
<Menu>
	<Menu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80 focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-1"
		aria-label="Layout options"
		title="Layout options"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="var(--color-surface-950)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<rect x="3" y="3" width="7" height="7" rx="1" fill="var(--color-primary-500)" class="{layoutState.feedColumns >= 1 ? '' : 'opacity-30'}" />
			<rect x="14" y="3" width="7" height="7" rx="1" fill="var(--color-primary-500)" class="{layoutState.feedColumns >= 2 ? '' : 'opacity-30'}" />
			<rect x="3" y="14" width="7" height="7" rx="1" fill="var(--color-primary-500)" class="{layoutState.feedColumns >= 3 ? '' : 'opacity-30'}" />
			<rect x="14" y="14" width="7" height="7" rx="1" fill="var(--color-primary-500)" class="{layoutState.feedColumns >= 4 ? '' : 'opacity-30'}" />
		</svg>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="var(--color-surface-950)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select layout</span>
	</Menu.Trigger>

	<Portal>
		<Menu.Positioner>
			<Menu.Content class="card bg-surface-100-900 w-48 p-2 shadow-xl z-[9999]">
				<div class="px-2 pb-2 text-xs font-medium text-surface-500 dark:text-surface-400 uppercase tracking-wider">
					Feeds
				</div>
				<div class="space-y-1 mb-3">
					{#each columnOptions as option (option.id)}
						<button
							type="button"
							onclick={() => setFeedColumns(option.id)}
							class="flex items-center gap-3 px-2 py-2 rounded-lg cursor-pointer transition-colors hover:bg-surface-200 dark:hover:bg-surface-800 w-full text-left"
						>
							{#if option.id === 1}
								<div class="w-10 shrink-0">
									<div class="h-2 w-6 rounded-sm bg-[var(--color-primary-500,#334155)]"></div>
								</div>
							{:else}
								<div class="grid {getColumnBlocks(option.id)} gap-1 w-10 shrink-0">
									{#each Array(option.id) as _, i (i)}
										<div class="h-2 rounded-sm bg-[var(--color-primary-500,#334155)]"></div>
									{/each}
								</div>
							{/if}
							<span class="flex-1 text-sm text-surface-950 dark:text-surface-50">{option.name}</span>
							{#if layoutState.feedColumns === option.id}
								<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 text-[var(--color-primary-500,#334155)]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polyline points="20 6 9 17 4 12"/>
								</svg>
							{/if}
						</button>
					{/each}
				</div>

				<Menu.Separator />

				<div class="px-2 py-2 text-xs font-medium text-surface-500 dark:text-surface-400 uppercase tracking-wider">
					Timeline
				</div>
				<div class="space-y-1">
					{#each timelineColumnOptions as option (option.id)}
						<button
							type="button"
							onclick={() => setTimelineColumns(option.id)}
							class="flex items-center gap-3 px-2 py-2 rounded-lg cursor-pointer transition-colors hover:bg-surface-200 dark:hover:bg-surface-800 w-full text-left"
						>
							{#if option.singleColumnPreview}
								<div class="w-10 shrink-0">
									<div class="h-2 w-6 rounded-sm bg-[var(--color-primary-500,#334155)]"></div>
								</div>
							{:else}
								<div class="grid {getColumnBlocks(option.id)} gap-1 w-10 shrink-0">
									{#each Array(option.id) as _, i (i)}
										<div class="h-2 rounded-sm bg-[var(--color-primary-500,#334155)]"></div>
									{/each}
								</div>
							{/if}
							<span class="flex-1 text-sm text-surface-950 dark:text-surface-50">{option.name}</span>
							{#if layoutState.timelineColumns === option.id}
								<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 text-[var(--color-primary-500,#334155)]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polyline points="20 6 9 17 4 12"/>
								</svg>
							{/if}
						</button>
					{/each}
				</div>
			</Menu.Content>
		</Menu.Positioner>
	</Portal>
</Menu>
{/if}
