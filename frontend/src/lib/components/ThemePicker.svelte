<script lang="ts">
	import { themeState, setTheme, themeStyles } from '$lib/stores/theme.svelte';
	import { fade, scale } from 'svelte/transition';

	type ThemeStyle = 'light' | 'dark' | 'retro80s' | 'matrix' | 'ocean' | 'sunset';

	let isOpen = $state(false);
	let buttonRef: HTMLButtonElement | null = $state(null);

	function toggleDropdown(event: MouseEvent) {
		event.stopPropagation();
		isOpen = !isOpen;
	}

	function selectTheme(theme: string) {
		setTheme(theme as ThemeStyle);
		isOpen = false;
	}

	function handleClickOutside(event: MouseEvent) {
        if (buttonRef && !buttonRef.contains(event.target as Node)) {
            isOpen = false;
        }
    }
    
    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === 'Escape') {
            isOpen = false;
        }
    }

	$effect(() => {
		if (isOpen) {
			document.addEventListener('click', handleClickOutside);
			return () => document.removeEventListener('click', handleClickOutside);
		}
	});

	function getThemePreview(theme: string): string {
		switch (theme) {
			case 'light': return 'linear-gradient(135deg, #ffffff 50%, #e2e8f0 50%)';
			case 'dark': return 'linear-gradient(135deg, #1e293b 50%, #0f172a 50%)';
			case 'retro80s': return 'linear-gradient(135deg, #ff2e63 50%, #e94560 50%)';
			case 'matrix': return 'linear-gradient(135deg, #00ff00 50%, #003b00 50%)';
			case 'ocean': return 'linear-gradient(135deg, #06b6d4 50%, #164e63 50%)';
			case 'sunset': return 'linear-gradient(135deg, #f97316 50%, #431407 50%)';
			default: return '#ccc';
		}
	}
</script>

<div class="relative">
	<button
		bind:this={buttonRef}
		onclick={toggleDropdown}
		class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
		aria-label="Select theme"
		title="Theme"
		aria-expanded={isOpen}
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<circle cx="12" cy="12" r="10"/>
			<circle cx="12" cy="12" r="4"/>
			<line x1="21.17" y1="8" x2="12" y2="8"/>
			<line x1="3.95" y1="6.06" x2="8.54" y2="14"/>
			<line x1="10.88" y1="21.94" x2="15.46" y2="14"/>
		</svg>
		<span class="sr-only">Select theme</span>
	</button>

	{#if isOpen}
		<div
			transition:scale={{ duration: 150, start: 0.95 }}
			class="absolute right-0 mt-2 w-56 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-1 z-50"
		>
			<div class="px-3 py-2 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
				Theme
			</div>
			{#each themeStyles as theme}
				<button
					onclick={() => selectTheme(theme.id)}
					class="w-full px-3 py-2 text-left hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors flex items-center gap-3"
					class:bg-slate-100={themeState.theme === theme.id}
					class:dark:bg-slate-700={themeState.theme === theme.id}
				>
					<span
						class="w-4 h-4 rounded-full border border-slate-300 dark:border-slate-600"
						style="background: {getThemePreview(theme.id)}"
					></span>
					<div class="flex-1">
						<div class="text-sm text-slate-700 dark:text-slate-200">{theme.name}</div>
						<div class="text-xs text-slate-500 dark:text-slate-400">{theme.description}</div>
					</div>
					{#if themeState.theme === theme.id}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
					{/if}
				</button>
			{/each}
		</div>
	{/if}
</div>
