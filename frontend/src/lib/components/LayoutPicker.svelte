<script lang="ts">
	import { layoutState, setTimelineColumns, columnOptions, type ColumnCount } from '$lib/stores/layout.svelte';
	import { scale } from 'svelte/transition';

	let isOpen = $state(false);
	let buttonRef: HTMLButtonElement | null = $state(null);

	function toggleDropdown(event: MouseEvent) {
		event.stopPropagation();
		isOpen = !isOpen;
	}

	function selectColumns(count: ColumnCount) {
		setTimelineColumns(count);
		isOpen = false;
	}

	function handleClickOutside(event: MouseEvent) {
		if (buttonRef && !buttonRef.contains(event.target as Node)) {
			isOpen = false;
		}
	}

	$effect(() => {
		if (isOpen) {
			document.addEventListener('click', handleClickOutside);
			return () => document.removeEventListener('click', handleClickOutside);
		}
	});

	function handleKeydown(event: KeyboardEvent) {
		if (!isOpen) return;
		
		if (event.key === 'Escape') {
			isOpen = false;
			buttonRef?.focus();
		}
	}

	function getGridIcon(columns: ColumnCount): string {
		switch (columns) {
			case 1: return 'M4 4h16v16H4z';
			case 2: return 'M10 4H4v16h6zM20 4h-6v16h6z';
			case 3: return 'M8 4H4v16h4zM14 4h-4v16h4zM20 4h-4v16h4z';
			case 4: return 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z';
			default: return 'M4 4h16v16H4z';
		}
	}

	function getPreviewDots(columns: ColumnCount): string[] {
		const dots: string[] = [];
		for (let i = 0; i < columns; i++) {
			dots.push(`dot-${i}`);
		}
		return dots;
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="relative">
	<button
		bind:this={buttonRef}
		onclick={toggleDropdown}
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:bg-slate-100 dark:hover:bg-slate-800"
		class:bg-slate-100={isOpen}
		class:dark:bg-slate-800={isOpen}
		style="opacity: {isOpen ? 1 : 0.7};"
		aria-label="Timeline layout"
		title="Timeline layout"
		aria-expanded={isOpen}
		aria-haspopup="true"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<rect x="3" y="3" width="7" height="7" rx="1" />
			<rect x="14" y="3" width="7" height="7" rx="1" />
			<rect x="3" y="14" width="7" height="7" rx="1" />
			<rect x="14" y="14" width="7" height="7" rx="1" />
		</svg>
		{#if layoutState.mounted && layoutState.timelineColumns > 1}
			<span class="text-xs text-slate-500 dark:text-slate-400 font-medium">{layoutState.timelineColumns}</span>
		{/if}
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select layout</span>
	</button>

	{#if isOpen}
		<div
			transition:scale={{ duration: 150, start: 0.95 }}
			class="absolute right-0 mt-2 w-48 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-2 z-50"
			role="radiogroup"
			aria-label="Column layout options"
		>
			<div class="px-3 py-1 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
				Columns
			</div>
			<div class="flex flex-col gap-0.5 px-1 mt-1" role="radiogroup">
				{#each columnOptions as option (option.id)}
					<button
						onclick={() => selectColumns(option.id)}
						class="px-2 py-1.5 text-left hover:bg-slate-100 dark:hover:bg-slate-700 rounded-md transition-colors flex items-center gap-3"
						class:bg-slate-100={layoutState.timelineColumns === option.id}
						class:dark:bg-slate-700={layoutState.timelineColumns === option.id}
						role="radio"
						aria-checked={layoutState.timelineColumns === option.id}
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
					</button>
				{/each}
			</div>
		</div>
	{/if}
</div>
