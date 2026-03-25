<script lang="ts">
	import { DropdownMenu } from 'bits-ui';
	import { layoutState, setTimelineColumns, setFeedColumns, columnOptions, type ColumnCount } from '$lib/stores/layout.svelte';
	import { spacing } from '$lib/design/tokens';

	let isMobile = $state(false);
	let activeSection = $state<'feeds' | 'timeline'>('feeds');

	$effect(() => {
		if (typeof window === 'undefined') return;
		
		const checkMobile = () => {
			isMobile = window.innerWidth < 768 || 'ontouchstart' in window;
		};
		
		checkMobile();
		window.addEventListener('resize', checkMobile);
		return () => window.removeEventListener('resize', checkMobile);
	});

	function getItemClass(selected: boolean): string {
		const base = `px-2 ${spacing.default} text-left hover:opacity-80 rounded-md transition-colors flex items-center gap-2 cursor-pointer outline-none`;
		return selected ? `${base} ring-2 ring-offset-1` : base;
	}

	function getColumnDots(count: number): string {
		if (count === 1) return 'grid-cols-1';
		if (count === 2) return 'grid-cols-2';
		return 'grid-cols-3';
	}
</script>

{#if !isMobile}
<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80 text-slate-700 dark:text-slate-300"
		aria-label="Layout options"
		title="Layout options"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<rect x="3" y="3" width="7" height="7" rx="1" fill={layoutState.mounted ? 'currentColor' : 'none'} />
			<rect x="14" y="3" width="7" height="7" rx="1" fill={layoutState.mounted && (layoutState.feedColumns >= 2 || layoutState.timelineColumns >= 2) ? 'currentColor' : 'none'} />
			<rect x="3" y="14" width="7" height="7" rx="1" fill={layoutState.mounted && (layoutState.feedColumns >= 3 || layoutState.timelineColumns >= 3) ? 'currentColor' : 'none'} />
			<rect x="14" y="14" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.feedColumns >= 4 ? 'currentColor' : 'none'} />
		</svg>
		{#if layoutState.mounted && (layoutState.feedColumns > 3 || layoutState.timelineColumns > 1)}
			<span class="text-xs font-medium">{layoutState.feedColumns}</span>
		{/if}
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select layout</span>
	</DropdownMenu.Trigger>

	<DropdownMenu.Portal>
	<DropdownMenu.Content
		class="z-50 w-56 rounded-xl shadow-lg p-3 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700"
		sideOffset={8}
	>
		<div class="flex gap-1 p-1 bg-slate-100 dark:bg-slate-800 rounded-lg mb-3">
			<button
				type="button"
				onclick={() => activeSection = 'feeds'}
				class="flex-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors cursor-pointer"
				class:bg-white={activeSection === 'feeds'}
				class:dark:bg-slate-700={activeSection === 'feeds'}
				class:text-slate-900={activeSection === 'feeds'}
				class:dark:text-white={activeSection === 'feeds'}
				class:text-slate-500={activeSection !== 'feeds'}
				class:dark:text-slate-400={activeSection !== 'feeds'}
			>
				Feeds
			</button>
			<button
				type="button"
				onclick={() => activeSection = 'timeline'}
				class="flex-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors cursor-pointer"
				class:bg-white={activeSection === 'timeline'}
				class:dark:bg-slate-700={activeSection === 'timeline'}
				class:text-slate-900={activeSection === 'timeline'}
				class:dark:text-white={activeSection === 'timeline'}
				class:text-slate-500={activeSection !== 'timeline'}
				class:dark:text-slate-400={activeSection !== 'timeline'}
			>
				Timeline
			</button>
		</div>

		{#if activeSection === 'feeds'}
			<div class="space-y-1">
				<div class="px-2 pb-2 text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
					Feed Columns
				</div>
				{#each columnOptions as option (option.id)}
					<DropdownMenu.Item
						onSelect={() => setFeedColumns(option.id)}
						class="{getItemClass(layoutState.feedColumns === option.id)} {layoutState.feedColumns === option.id ? 'bg-slate-100 dark:bg-slate-800' : ''}"
					>
						<div class="grid {getColumnDots(option.id)} gap-1 w-12 shrink-0">
							{#each Array(option.id) as _, i (`dot-${i}`)}
								<div class="h-2 rounded-sm bg-slate-400 dark:bg-slate-500"></div>
							{/each}
						</div>
						<div class="flex-1 min-w-0">
							<div class="text-sm">{option.name}</div>
						</div>
						{#if layoutState.feedColumns === option.id}
							<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 text-blue-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="20 6 9 17 4 12"/>
							</svg>
						{/if}
					</DropdownMenu.Item>
				{/each}
			</div>
		{:else}
			<div class="space-y-1">
				<div class="px-2 pb-2 text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
					Timeline Columns
				</div>
				<DropdownMenu.Item
					onSelect={() => setTimelineColumns(1)}
					class="{getItemClass(layoutState.timelineColumns === 1)} {layoutState.timelineColumns === 1 ? 'bg-slate-100 dark:bg-slate-800' : ''}"
				>
					<div class="w-12 shrink-0">
						<div class="h-2 w-8 rounded-sm bg-slate-400 dark:bg-slate-500"></div>
					</div>
					<div class="flex-1 min-w-0">
						<div class="text-sm">1 Column</div>
					</div>
					{#if layoutState.timelineColumns === 1}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 text-blue-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
					{/if}
				</DropdownMenu.Item>
				{#each columnOptions as option (option.id)}
					<DropdownMenu.Item
						onSelect={() => setTimelineColumns(option.id)}
						class="{getItemClass(layoutState.timelineColumns === option.id)} {layoutState.timelineColumns === option.id ? 'bg-slate-100 dark:bg-slate-800' : ''}"
					>
						<div class="grid {getColumnDots(option.id)} gap-1 w-12 shrink-0">
							{#each Array(option.id) as _, i (`dot-${i}`)}
								<div class="h-2 rounded-sm bg-slate-400 dark:bg-slate-500"></div>
							{/each}
						</div>
						<div class="flex-1 min-w-0">
							<div class="text-sm">{option.name}</div>
						</div>
						{#if layoutState.timelineColumns === option.id}
							<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 text-blue-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="20 6 9 17 4 12"/>
							</svg>
						{/if}
					</DropdownMenu.Item>
				{/each}
			</div>
		{/if}
	</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>
{/if}