<script lang="ts">
	import { cn } from '$lib/utils';
	import { themeState } from '$lib/stores/theme.svelte';

	interface AnimatedThemeTogglerProps {
		class?: string;
		title?: string;
	}

	let { class: className, title = "Toggle theme", ...props }: AnimatedThemeTogglerProps = $props();

	let buttonRef: HTMLButtonElement | null = $state(null);

	const toggleTheme = (event: MouseEvent) => {
		if (!buttonRef) return;

		const x = event.clientX;
		const y = event.clientY;
		
		document.documentElement.style.setProperty('--x', `${x}px`);
		document.documentElement.style.setProperty('--y', `${y}px`);

		const newTheme = themeState.theme === 'light' ? 'dark' : 'light';

		if (!document.startViewTransition) {
			themeState.theme = newTheme;
			document.documentElement.classList.toggle('dark', newTheme === 'dark');
			localStorage.setItem('quickheadlines-theme', newTheme);
			return;
		}

		document.startViewTransition(() => {
			themeState.theme = newTheme;
			document.documentElement.classList.toggle('dark', newTheme === 'dark');
			localStorage.setItem('quickheadlines-theme', newTheme);
		});
	};
</script>

<button
	bind:this={buttonRef}
	onclick={toggleTheme}
	class={cn('p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors', className)}
	aria-label="Toggle theme"
	title={title}
	{...props}
>
	{#if themeState.theme === 'dark'}
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-yellow-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<circle cx="12" cy="12" r="5"/>
			<line x1="12" y1="1" x2="12" y2="3"/>
			<line x1="12" y1="21" x2="12" y2="23"/>
			<line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/>
			<line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/>
			<line x1="1" y1="12" x2="3" y2="12"/>
			<line x1="21" y1="12" x2="23" y2="12"/>
			<line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/>
			<line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
		</svg>
	{:else}
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-600 dark:text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
		</svg>
	{/if}
	<span class="sr-only">Toggle theme</span>
</button>
