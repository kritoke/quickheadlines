<script lang="ts">
	import { onMount } from 'svelte';
	import { themeState } from '$lib/stores/theme.svelte';

	let x = $state(0);
	let y = $state(0);

	onMount(() => {
		function handleMouseMove(e: MouseEvent) {
			x = e.clientX;
			y = e.clientY;
		}

		window.addEventListener('mousemove', handleMouseMove);
		return () => window.removeEventListener('mousemove', handleMouseMove);
	});

	let enabled = $derived(themeState.coolMode);
</script>

{#if enabled}
	<div
		class="fixed inset-0 pointer-events-none z-[9999]"
		aria-hidden="true"
	>
		<div
			class="absolute w-20 h-20 rounded-full"
			style="left: {x - 40}px; top: {y - 40}px; background: rgba(150, 173, 141, 0.3); filter: blur(12px); transition: left 0.1s ease-out, top 0.1s ease-out;"
		></div>
		<div
			class="absolute w-4 h-4 rounded-full"
			style="left: {x - 8}px; top: {y - 8}px; background: #96ad8d; transition: left 0.05s ease-out, top 0.05s ease-out;"
		></div>
	</div>
{/if}
