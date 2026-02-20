<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { themeState, initTheme } from '$lib/stores/theme.svelte';
	import { onNavigate, type Navigation } from '$app/navigation';
	import CursorTrail from '$lib/components/CursorTrail.svelte';
	
	let { children } = $props();
	
	onMount(() => {
		initTheme();
	});

	onNavigate((navigation: Navigation) => {
		if (!document.startViewTransition) return;

		return new Promise<void>((resolve) => {
			document.startViewTransition(async () => {
				resolve();
				await navigation.complete;
			});
		});
	});
</script>

{#if themeState.mounted}
	<CursorTrail />
	<div id="app" class="min-h-screen bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 transition-colors duration-200">
		{@render children()}
	</div>
{:else}
	<div class="min-h-screen bg-white text-slate-900 flex items-center justify-center">
		Loading...
	</div>
{/if}
