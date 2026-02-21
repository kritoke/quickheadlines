<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState } from '$lib/stores/theme.svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	function handleMouseMove(event: MouseEvent) {
		coords.set({ x: event.clientX, y: event.clientY });
		setTimeout(() => trail.set({ x: event.clientX, y: event.clientY }), 50);
	}
</script>

<svelte:window onmousemove={handleMouseMove} />

{#if themeState.coolMode}
	<div 
		class="pointer-events-none fixed z-50 h-3 w-3 rounded-full"
		style="left: {$coords.x}px; top: {$coords.y}px; background: #96ad8d;"
	></div>
	<div 
		class="pointer-events-none fixed z-40 h-8 w-8 rounded-full"
		style="left: {$trail.x - 12}px; top: {$trail.y - 12}px; background: rgba(150, 173, 141, 0.3); filter: blur(12px);"
	></div>
{/if}
