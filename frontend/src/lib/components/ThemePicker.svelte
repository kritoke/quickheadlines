<script lang="ts">
	import { Popover, Portal } from '@skeletonlabs/skeleton-svelte';
	import { themeState, setTheme, ALL_THEMES, isNoveltyTheme } from '$lib/stores/theme.svelte';

	let searchQuery = $state('');

	const standardThemes = ALL_THEMES.filter(t => !isNoveltyTheme(t));
	const noveltyThemes = ALL_THEMES.filter(t => isNoveltyTheme(t));

	let filteredStandard = $derived(
		searchQuery
			? standardThemes.filter(t => t.includes(searchQuery.toLowerCase()))
			: standardThemes
	);

	let filteredNovelty = $derived(
		searchQuery
			? noveltyThemes.filter(t => t.includes(searchQuery.toLowerCase()))
			: noveltyThemes
	);

	function selectTheme(theme: string) {
		setTheme(theme);
	}
</script>

<Popover>
	<Popover.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80 text-surface-950 dark:text-surface-50 focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-1"
		title="Theme"
	>
		<span
			class="w-5 h-5 rounded-full border border-surface-300 dark:border-surface-600 shrink-0"
			style="background-color: var(--color-primary-500);"
		></span>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select theme</span>
	</Popover.Trigger>

	<Portal>
		<Popover.Positioner>
			<Popover.Content class="card bg-surface-100-900 w-80 shadow-xl p-3 z-[9999]">
				<div class="pb-2">
					<input
						type="text"
						bind:value={searchQuery}
						placeholder="Search themes..."
						class="w-full px-3 py-2 text-sm bg-surface-200 dark:bg-surface-800 border border-surface-300 dark:border-surface-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 text-surface-950 dark:text-surface-50 placeholder-surface-400"
					/>
				</div>

				{#if filteredStandard.length > 0}
					<div class="pb-1 text-xs font-semibold uppercase tracking-wider text-surface-500 dark:text-surface-400">
						Standard
					</div>
					<div class="grid grid-cols-2 gap-2 mb-3">
						{#each filteredStandard as theme (theme)}
							<button
								type="button"
								onclick={() => selectTheme(theme)}
								class="flex items-center gap-2 px-2 py-1.5 rounded-md transition-colors hover:bg-surface-200 dark:hover:bg-surface-800 cursor-pointer outline-none {themeState.theme === theme ? 'bg-surface-200 dark:bg-surface-800 ring-1 ring-primary-500' : ''}"
							>
								<span
									class="w-4 h-4 rounded-full shrink-0"
									data-theme={theme}
									style="background-color: var(--color-primary-500);"
								></span>
								<span class="text-sm capitalize text-surface-950 dark:text-surface-50 truncate">{theme}</span>
							</button>
						{/each}
					</div>
				{/if}

				{#if filteredNovelty.length > 0}
					<div class="pb-1 text-xs font-semibold uppercase tracking-wider text-surface-500 dark:text-surface-400">
						Novelty
					</div>
					<div class="grid grid-cols-2 gap-2">
						{#each filteredNovelty as theme (theme)}
							<button
								type="button"
								onclick={() => selectTheme(theme)}
								class="flex items-center gap-2 px-2 py-1.5 rounded-md transition-colors hover:bg-surface-200 dark:hover:bg-surface-800 cursor-pointer outline-none {themeState.theme === theme ? 'bg-surface-200 dark:bg-surface-800 ring-1 ring-primary-500' : ''}"
							>
								<span
									class="w-4 h-4 rounded-full shrink-0"
									data-theme={theme}
									style="background-color: var(--color-primary-500);"
								></span>
								<span class="text-sm capitalize text-surface-950 dark:text-surface-50 truncate">{theme}</span>
							</button>
						{/each}
					</div>
				{/if}

				{#if searchQuery && filteredStandard.length === 0 && filteredNovelty.length === 0}
					<div class="py-4 text-center text-sm text-surface-500 dark:text-surface-400">
						No themes found
					</div>
				{/if}
			</Popover.Content>
		</Popover.Positioner>
	</Portal>
</Popover>
