<script lang="ts">
	import { Sun, Moon } from 'lucide-svelte';
	import { cn } from '$lib/utils';
	import { themeState } from '$lib/stores/theme.svelte';

	interface AnimatedThemeTogglerProps {
		class?: string;
		duration?: number;
	}

	let { class: className, duration = 400, ...props }: AnimatedThemeTogglerProps = $props();

	let buttonRef: HTMLButtonElement | null = $state(null);

	const toggleTheme = async () => {
		if (!buttonRef) return;

		const newTheme = themeState.theme === 'light' ? 'dark' : 'light';

		if (!document.startViewTransition) {
			themeState.theme = newTheme;
			document.documentElement.classList.toggle('dark', newTheme === 'dark');
			localStorage.setItem('quickheadlines-theme', newTheme);
			return;
		}

		const transition = document.startViewTransition(() => {
			themeState.theme = newTheme;
			document.documentElement.classList.toggle('dark', newTheme === 'dark');
			localStorage.setItem('quickheadlines-theme', newTheme);
		});

		await transition.ready;

		const { top, left, width, height } = buttonRef.getBoundingClientRect();
		const x = left + width / 2;
		const y = top + height / 2;
		const maxRadius = Math.hypot(
			Math.max(left, window.innerWidth - left),
			Math.max(top, window.innerHeight - top)
		);

		document.documentElement.animate(
			{
				clipPath: [
					`circle(0px at ${x}px ${y}px)`,
					`circle(${maxRadius}px at ${x}px ${y}px)`
				]
			},
			{
				duration,
				easing: 'ease-in-out',
				pseudoElement: '::view-transition-new(root)'
			}
		);
	};
</script>

<button
	bind:this={buttonRef}
	onclick={toggleTheme}
	class={cn('p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors', className)}
	aria-label="Toggle theme"
	{...props}
>
	{#if themeState.theme === 'dark'}
		<Sun class="w-5 h-5 text-yellow-500" />
	{:else}
		<Moon class="w-5 h-5 text-slate-600 dark:text-slate-400" />
	{/if}
	<span class="sr-only">Toggle theme</span>
</button>
