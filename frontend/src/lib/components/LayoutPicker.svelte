<script lang="ts">
	import { DropdownMenu } from 'bits-ui';
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
		...columnOptions
	];
</script>

{#snippet columnOption(option: ColumnOptionData, isSelected: boolean, onSelect: () => void)}
	<DropdownMenu.Item
		onSelect={onSelect}
		class="flex items-center gap-3 px-2 py-2 rounded-lg cursor-pointer transition-colors hover:theme-bg-secondary {isSelected ? 'theme-bg-secondary' : ''}"
	>
		{#if option.singleColumnPreview}
			<div class="w-10 shrink-0">
				<div class="h-2 w-6 rounded-sm theme-accent-bg"></div>
			</div>
		{:else}
			<div class="grid {getColumnBlocks(option.id)} gap-1 w-10 shrink-0">
				{#each Array(option.id) as _, i (i)}
					<div class="h-2 rounded-sm theme-accent-bg"></div>
				{/each}
			</div>
		{/if}
		<span class="flex-1 text-sm theme-text-primary">{option.name}</span>
		{#if isSelected}
			<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 theme-accent" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<polyline points="20 6 9 17 4 12"/>
			</svg>
		{/if}
	</DropdownMenu.Item>
{/snippet}

{#if !isMobile}
<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80 theme-text-primary focus-visible:ring-2 focus-visible:ring-[var(--theme-accent)] focus-visible:ring-offset-1"
		aria-label="Layout options"
		title="Layout options"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<rect x="3" y="3" width="7" height="7" rx="1" fill="currentColor" class="{layoutState.feedColumns >= 1 ? '' : 'opacity-30'}" />
			<rect x="14" y="3" width="7" height="7" rx="1" fill="currentColor" class="{layoutState.feedColumns >= 2 ? '' : 'opacity-30'}" />
			<rect x="3" y="14" width="7" height="7" rx="1" fill="currentColor" class="{layoutState.feedColumns >= 3 ? '' : 'opacity-30'}" />
			<rect x="14" y="14" width="7" height="7" rx="1" fill="currentColor" class="{layoutState.feedColumns >= 4 ? '' : 'opacity-30'}" />
		</svg>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select layout</span>
	</DropdownMenu.Trigger>

	<DropdownMenu.Portal>
	<DropdownMenu.Content
		class="z-50 w-48 rounded-xl shadow-lg p-2 theme-bg-primary theme-border border"
		sideOffset={8}
	>
		<div class="px-2 pb-2 text-xs font-medium theme-text-secondary uppercase tracking-wider">
			Feeds
		</div>
		<div class="space-y-1 mb-3">
			{#each columnOptions as option (option.id)}
				{@render columnOption(option, layoutState.feedColumns === option.id, () => setFeedColumns(option.id))}
			{/each}
		</div>

		<div class="px-2 py-2 text-xs font-medium theme-text-secondary uppercase tracking-wider border-t theme-border pt-2 mt-1">
			Timeline
		</div>
		<div class="space-y-1">
			{#each timelineColumnOptions as option (option.id)}
				{@render columnOption(option, layoutState.timelineColumns === option.id, () => setTimelineColumns(option.id))}
			{/each}
		</div>
	</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>
{/if}
