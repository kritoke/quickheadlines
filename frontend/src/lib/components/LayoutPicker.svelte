<script lang="ts">
	import { DropdownMenu } from 'bits-ui';
	import { layoutState, setTimelineColumns, columnOptions, type ColumnCount } from '$lib/stores/layout.svelte';

	let isMobile = $state(false);

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
		const base = "px-2 py-1.5 text-left hover:bg-slate-100 dark:hover:bg-slate-700 rounded-md transition-colors flex items-center gap-3 cursor-pointer outline-none";
		return selected ? `${base} bg-slate-100 dark:bg-slate-700` : base;
	}
</script>

{#if !isMobile}
<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:bg-slate-100 dark:hover:bg-slate-800"
		aria-label="Timeline layout"
		title="Timeline layout"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<rect x="3" y="3" width="7" height="7" rx="1" fill={layoutState.mounted ? 'currentColor' : 'none'} />
			<rect x="14" y="3" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.timelineColumns >= 2 ? 'currentColor' : 'none'} />
			<rect x="3" y="14" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.timelineColumns >= 3 ? 'currentColor' : 'none'} />
			<rect x="14" y="14" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.timelineColumns === 4 ? 'currentColor' : 'none'} />
		</svg>
		{#if layoutState.mounted && layoutState.timelineColumns > 1}
			<span class="text-xs text-slate-500 dark:text-slate-400 font-medium">{layoutState.timelineColumns}</span>
		{/if}
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select layout</span>
	</DropdownMenu.Trigger>

	<DropdownMenu.Portal>
		<DropdownMenu.Content
			class="z-50 w-48 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-2"
			sideOffset={8}
		>
			<div class="px-3 py-1 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
				Columns
			</div>
			{#each columnOptions as option (option.id)}
				<DropdownMenu.Item
					onSelect={() => setTimelineColumns(option.id)}
					class={getItemClass(layoutState.timelineColumns === option.id)}
				>
					<div class="flex items-center gap-0.5 w-12 shrink-0">
						{#each Array(option.id) as _, i (`dot-${i}`)}
							<div class="w-2 h-2 rounded-sm bg-slate-400 dark:bg-slate-500"></div>
						{/each}
					</div>
					<div class="flex-1 min-w-0">
						<div class="text-sm text-slate-700 dark:text-slate-200">{option.name}</div>
					</div>
					{#if layoutState.timelineColumns === option.id}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-500 dark:text-slate-400 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
					{/if}
				</DropdownMenu.Item>
			{/each}
		</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>
{/if}
