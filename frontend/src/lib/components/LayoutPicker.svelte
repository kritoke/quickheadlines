<script lang="ts">
	import { DropdownMenu } from 'bits-ui';
	import { layoutState, setTimelineColumns, columnOptions, type ColumnCount } from '$lib/stores/layout.svelte';
	import { themeState, getDotIndicatorColors, getThemeAccentColors } from '$lib/stores/theme.svelte';

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

	let dotColor = $derived(getDotIndicatorColors(themeState.theme));
	let accentColors = $derived(getThemeAccentColors(themeState.theme));

	function getItemClass(selected: boolean): string {
		const base = "px-2 py-1.5 text-left hover:opacity-80 rounded-md transition-colors flex items-center gap-3 cursor-pointer outline-none";
		return selected ? `${base} ring-2 ring-offset-1` : base;
	}
</script>

{#if !isMobile}
<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80"
		style="color: {accentColors.text}"
		aria-label="Timeline layout"
		title="Timeline layout"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<rect x="3" y="3" width="7" height="7" rx="1" fill={layoutState.mounted ? 'currentColor' : 'none'} />
			<rect x="14" y="3" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.timelineColumns >= 2 ? 'currentColor' : 'none'} />
			<rect x="3" y="14" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.timelineColumns >= 3 ? 'currentColor' : 'none'} />
			<rect x="14" y="14" width="7" height="7" rx="1" fill={layoutState.mounted && layoutState.timelineColumns === 4 ? 'currentColor' : 'none'} />
		</svg>
		{#if layoutState.mounted && layoutState.timelineColumns > 1}
			<span class="text-xs font-medium">{layoutState.timelineColumns}</span>
		{/if}
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select layout</span>
	</DropdownMenu.Trigger>

	<DropdownMenu.Portal>
		<DropdownMenu.Content
			class="z-50 w-48 rounded-lg shadow-lg py-2"
			style="background-color: {accentColors.bg}; border-color: {accentColors.border}; color: {accentColors.text}"
			sideOffset={8}
		>
			<div class="px-3 py-1 text-xs font-semibold uppercase tracking-wider opacity-70">
				Columns
			</div>
			{#each columnOptions as option (option.id)}
				<DropdownMenu.Item
					onSelect={() => setTimelineColumns(option.id)}
					class={getItemClass(layoutState.timelineColumns === option.id)}
					style="background-color: {layoutState.timelineColumns === option.id ? accentColors.bgSecondary : 'transparent'}; color: {accentColors.text}"
				>
					<div class="flex items-center gap-0.5 w-12 shrink-0">
						{#each Array(option.id) as _, i (`dot-${i}`)}
							<div class="w-2 h-2 rounded-sm" style="background-color: {dotColor}"></div>
						{/each}
					</div>
					<div class="flex-1 min-w-0">
						<div class="text-sm">{option.name}</div>
					</div>
					{#if layoutState.timelineColumns === option.id}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: {accentColors.accent}">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
					{/if}
				</DropdownMenu.Item>
			{/each}
		</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>
{/if}
