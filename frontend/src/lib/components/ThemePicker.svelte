<script lang="ts">
	import { DropdownMenu } from 'bits-ui';
	import { themeState, setTheme, themeStyles, getThemeAccentColors, getThemePreview, type ThemeStyle } from '$lib/stores/theme.svelte';

	let accentColors = $derived(getThemeAccentColors(themeState.theme));
	let themePreviews = $derived(
		themeStyles.reduce((acc, t) => {
			acc[t.id] = getThemePreview(t.id);
			return acc;
		}, {} as Record<ThemeStyle, string>)
	);

	function selectTheme(theme: ThemeStyle) {
		setTheme(theme);
	}
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class="flex items-center gap-1 p-2 rounded-lg transition-colors hover:opacity-80"
		style="color: {accentColors.text}"
		title="Theme"
	>
		<span
			class="w-5 h-5 rounded-full border shrink-0"
			style="border-color: {accentColors.border}; background: {themePreviews[themeState.theme]}"
		></span>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<polyline points="6 9 12 15 18 9"/>
		</svg>
		<span class="sr-only">Select theme</span>
	</DropdownMenu.Trigger>

	<DropdownMenu.Portal>
		<DropdownMenu.Content
			class="z-50 w-80 rounded-lg shadow-lg py-2"
			style="background-color: {accentColors.bg}; border-color: {accentColors.border}; color: {accentColors.text}"
			sideOffset={8}
		>
			<div class="px-3 py-1 text-xs font-semibold uppercase tracking-wider opacity-70">
				Theme
			</div>
			<div class="grid grid-cols-2 gap-1 px-1 mt-1">
				{#each themeStyles as theme (theme.id)}
					<DropdownMenu.Item
						onSelect={() => selectTheme(theme.id)}
						class="px-2 py-1.5 text-left hover:opacity-80 rounded-md transition-colors flex items-center gap-2 cursor-pointer outline-none"
						style="background-color: {themeState.theme === theme.id ? accentColors.bgSecondary : 'transparent'}"
					>
						<span
							class="w-4 h-4 rounded-full border shrink-0"
							style="border-color: {accentColors.border}; background: {themePreviews[theme.id]}"
						></span>
						<div class="flex-1 min-w-0">
							<div class="text-sm truncate">{theme.name}</div>
						</div>
						{#if themeState.theme === theme.id}
							<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: {accentColors.accent}">
								<polyline points="20 6 9 17 4 12"/>
							</svg>
						{/if}
					</DropdownMenu.Item>
				{/each}
			</div>
		</DropdownMenu.Content>
	</DropdownMenu.Portal>
</DropdownMenu.Root>
