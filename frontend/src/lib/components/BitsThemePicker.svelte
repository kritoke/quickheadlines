<script lang="ts">
	import { Select } from 'bits-ui';
	import { themeState, setTheme, themeStyles } from '$lib/stores/theme.svelte';

	function getThemePreview(theme: string): string {
		switch (theme) {
			case 'light': return 'linear-gradient(135deg, #ffffff 50%, #e2e8f0 50%)';
			case 'dark': return 'linear-gradient(135deg, #1e293b 50%, #0f172a 50%)';
			case 'retro80s': return 'linear-gradient(135deg, #00d4ff 50%, #ff2e63 50%)';
			case 'matrix': return 'linear-gradient(135deg, #22c55e 50%, #166534 50%)';
			case 'ocean': return 'linear-gradient(135deg, #06b6d4 50%, #f472b6 50%)';
			case 'sunset': return 'linear-gradient(135deg, #f97316 50%, #431407 50%)';
			case 'hotdog': return 'linear-gradient(135deg, #008080 50%, #fff59d 50%)';
			case 'dracula': return 'linear-gradient(135deg, #bd93f9 50%, #282a36 50%)';
			case 'nord': return 'linear-gradient(135deg, #88c0d0 50%, #2e3440 50%)';
			case 'cyberpunk': return 'linear-gradient(135deg, #ff00ff 50%, #00ffff 50%)';
			case 'forest': return 'linear-gradient(135deg, #4ade80 50%, #1a2e1a 50%)';
			case 'coffee': return 'linear-gradient(135deg, #d97706 50%, #2c1810 50%)';
			case 'vaporwave': return 'linear-gradient(135deg, #ff71ce 50%, #b967ff 50%)';
			default: return '#ccc';
		}
	}

	let selectedTheme = $state(themeState.theme);

	$effect(() => {
		selectedTheme = themeState.theme;
	});

	function handleValueChange(value: string) {
		selectedTheme = value as typeof themeState.theme;
		setTheme(value as typeof themeState.theme);
	}
</script>

<Select.Root value={selectedTheme} onValueChange={handleValueChange}>
	<Select.Trigger class="flex items-center gap-1 p-2 rounded-lg transition-colors" aria-label="Select theme">
		<span
			class="w-5 h-5 rounded-full border border-slate-300 dark:border-slate-600 shrink-0"
			style="background: {getThemePreview(selectedTheme)}"
		></span>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 text-slate-500 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
	</Select.Trigger>
	
	<Select.Portal>
		<Select.Content class="absolute right-0 mt-2 w-80 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-2 z-50">
			<div class="px-3 py-1 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
				Theme
			</div>
			<div class="grid grid-cols-2 gap-1 px-1 mt-1">
				{#each themeStyles as theme}
					<Select.Item 
						value={theme.id}
						class="px-2 py-1.5 text-left hover:bg-slate-100 dark:hover:bg-slate-700 rounded-md transition-colors flex items-center gap-2"
					>
						<span
							class="w-4 h-4 rounded-full border border-slate-300 dark:border-slate-600 shrink-0"
							style="background: {getThemePreview(theme.id)}"
						></span>
						<div class="flex-1 min-w-0">
							<div class="text-sm text-slate-700 dark:text-slate-200 truncate">{theme.name}</div>
						</div>
						{#if selectedTheme === theme.id}
							<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-500 dark:text-slate-400 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="20 6 9 17 4 12"/>
							</svg>
						{/if}
					</Select.Item>
				{/each}
			</div>
		</Select.Content>
	</Select.Portal>
</Select.Root>