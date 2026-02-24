<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState, getCursorColors } from '$lib/stores/theme.svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	let cursorColors = $derived(getCursorColors(themeState.theme));

	function handleMove(x: number, y: number) {
		coords.set({ x, y });
		setTimeout(() => trail.set({ x, y }), 50);
	}

	function handleMouseMove(event: MouseEvent) {
		handleMove(event.clientX, event.clientY);
	}

	function handleTouchMove(event: TouchEvent) {
		if (event.touches.length > 0) {
			const touch = event.touches[0];
			handleMove(touch.clientX, touch.clientY);
		}
	}
</script>

<svelte:window onmousemove={handleMouseMove} ontouchmove={handleTouchMove} />

{#if themeState.coolMode}
	<div 
		class="pointer-events-none"
		style="position: fixed; z-index: 9999999; left: {$coords.x}px; top: {$coords.y}px; width: 0.75rem; height: 0.75rem; border-radius: 9999px; background: {cursorColors.primary}; pointer-events: none;"
	></div>
	<div 
		class="pointer-events-none"
		style="position: fixed; z-index: 9999998; left: {$trail.x - 12}px; top: {$trail.y - 12}px; width: 2rem; height: 2rem; border-radius: 9999px; background: {cursorColors.trail}; filter: blur(12px); pointer-events: none;"
	></div>
{/if}
