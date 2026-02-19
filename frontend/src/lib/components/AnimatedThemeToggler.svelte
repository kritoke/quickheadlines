<script lang="ts">
	import { Sun, Moon } from 'lucide-svelte';
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
		<Sun class="w-5 h-5 text-yellow-500" />
	{:else}
		<Moon class="w-5 h-5 text-slate-600 dark:text-slate-400" />
	{/if}
	<span class="sr-only">Toggle theme</span>
</button>
