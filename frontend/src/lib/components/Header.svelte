<script lang="ts">
	import { themeState, toggleCoolMode, getThemeAccentColors } from '$lib/stores/theme.svelte';
	import ThemePicker from './ThemePicker.svelte';
	
	let themeColors = $derived(getThemeAccentColors(themeState.theme));
</script>

<header 
	class="sticky top-0 backdrop-blur border-b z-20"
	style="background-color: {themeColors.bg}cc; border-color: {themeColors.border}; color: {themeColors.text};"
	data-name="main-header"
>
	<div class="max-w-7xl mx-auto px-2 sm:px-4 py-2 sm:py-3 flex items-center justify-between">
		<div class="flex items-center gap-2 sm:gap-3">
			<a href="/" class="flex items-center gap-2 sm:gap-3 hover:opacity-80 transition-opacity">
				<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
				<h1 class="text-lg sm:text-xl font-bold hidden sm:block" style="color: {themeColors.text};">
					QuickHeadlines
				</h1>
			</a>
		</div>
		<div class="flex items-center gap-1 sm:gap-2">
			<slot name="left" />
			<a href="/timeline" class="text-xs sm:text-sm hover:underline sm:mr-2" style="color: {themeColors.accent};">
				Timeline
			</a>
			<button
				onclick={toggleCoolMode}
				class="p-1.5 sm:p-2 rounded-lg transition-colors"
				style="color: {themeColors.text};"
				aria-label="Toggle cursor trail"
				title="Cursor trail"
			>
				<svg 
					class="w-5 h-5 transition-colors duration-200"
					style="color: {themeState.coolMode ? '#6b8e5f' : themeColors.text};"
					viewBox="0 0 24 24" 
					fill="currentColor"
				>
					<path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z" />
					<path d="M13 13l6 6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" />
				</svg>
			</button>
			<ThemePicker />
		</div>
	</div>
</header>
