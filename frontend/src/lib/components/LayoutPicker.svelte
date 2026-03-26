<script lang="ts">
	import { DropdownMenu } from 'bits-ui';
	import { layoutState, setTimelineColumns, setFeedColumns, columnOptions, type ColumnCount } from '$lib/stores/layout.svelte';

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
</script>

{#if !isMobile}
<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80 theme-text-primary"
		aria-label="Layout options"
		title="Layout options"
	>
		<div class="grid grid-cols-2 gap-1 w-5 h-5">
			{#each Array(4) as _, i (i)}
				<div class="transition-all rounded-sm {i < layoutState.feedColumns ? 'theme-accent-bg' : 'theme-text-secondary/30'}"></div>
			{/each}
		</div>
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
		<div class="px-2 pb-2 text-xs font-medium theme-text-secondary">
			Feeds
		</div>
		<div class="flex gap-2 mb-2">
			{#each columnOptions as option (option.id)}
				<DropdownMenu.Item
					onSelect={() => setFeedColumns(option.id)}
					class="flex-1 flex flex-col items-center gap-2 p-3 rounded-lg cursor-pointer transition-colors hover:theme-bg-secondary {layoutState.feedColumns === option.id ? 'theme-bg-secondary' : ''}"
				>
					<div class="grid grid-cols-2 gap-1 w-6 h-6">
						{#each Array(4) as _, i (i)}
							<div class="rounded-sm transition-all {i < option.id ? 'theme-accent-bg' : 'theme-text-secondary/30'}"></div>
						{/each}
					</div>
					<span class="text-xs theme-text-primary">{option.id}</span>
				</DropdownMenu.Item>
			{/each}
		</div>

		<div class="px-2 py-2 text-xs font-medium theme-text-secondary border-t theme-border pt-2 mt-1">
			Timeline
		</div>
		<div class="flex gap-2">
			<DropdownMenu.Item
				onSelect={() => setTimelineColumns(1)}
				class="flex-1 flex flex-col items-center gap-2 p-3 rounded-lg cursor-pointer transition-colors hover:theme-bg-secondary {layoutState.timelineColumns === 1 ? 'theme-bg-secondary' : ''}"
			>
				<div class="w-7 h-5 flex rounded-sm overflow-hidden">
					<div class="w-1/2 h-full theme-accent-bg"></div>
					<div class="w-1/2 h-full theme-text-secondary/30"></div>
				</div>
				<span class="text-xs theme-text-primary">1</span>
			</DropdownMenu.Item>
			{#each columnOptions as option (option.id)}
				<DropdownMenu.Item
					onSelect={() => setTimelineColumns(option.id)}
					class="flex-1 flex flex-col items-center gap-2 p-3 rounded-lg cursor-pointer transition-colors hover:theme-bg-secondary {layoutState.timelineColumns === option.id ? 'theme-bg-secondary' : ''}"
				>
					<div class="grid grid-cols-2 gap-1 w-6 h-6">
						{#each Array(4) as _, i (i)}
							<div class="rounded-sm transition-all {i < option.id ? 'theme-accent-bg' : 'theme-text-secondary/30'}"></div>
						{/each}
					</div>
					<span class="text-xs theme-text-primary">{option.id}</span>
				</DropdownMenu.Item>
			{/each}
		</div>
	</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>
{/if}