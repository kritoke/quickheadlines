<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { themeStore } from '$lib/stores/theme.svelte';
	
	let { children } = $props();
	
	onMount(() => {
		themeStore.init();
	});
</script>

{#if themeStore.isMounted}
<div id="app" class="min-h-screen bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 transition-colors duration-200">
	{@render children()}
</div>
{:else}
<div class="min-h-screen bg-white text-slate-900 flex items-center justify-center">
	Loading...
</div>
{/if}
