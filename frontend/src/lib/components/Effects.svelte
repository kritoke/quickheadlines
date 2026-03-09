<script lang="ts">
	import { themeState, getCursorColors } from '$lib/stores/theme.svelte';

	let coords = $state({ x: -100, y: -100 });
	let trail = $state({ x: -100, y: -100 });
	
	let cursorColors = $derived(getCursorColors(themeState.theme));
	let enabled = $derived(themeState.mounted && themeState.effects);

	let trailTimeout: ReturnType<typeof setTimeout> | undefined;
	let mouseX = 0;
	let mouseY = 0;

	function handleMouseMove(e: MouseEvent) {
		if (!enabled) return;
		coords = { x: e.clientX, y: e.clientY };
		clearTimeout(trailTimeout);
		trailTimeout = setTimeout(() => {
			trail = { x: e.clientX, y: e.clientY };
		}, 50);
		mouseX = e.clientX;
		mouseY = e.clientY;
	}

	function handleTouchMove(e: TouchEvent) {
		if (!enabled || e.touches.length === 0) return;
		const touch = e.touches[0];
		coords = { x: touch.clientX, y: touch.clientY };
		clearTimeout(trailTimeout);
		trailTimeout = setTimeout(() => {
			trail = { x: touch.clientX, y: touch.clientY };
		}, 50);
		mouseX = touch.clientX;
		mouseY = touch.clientY;
	}
</script>

<svelte:window onmousemove={handleMouseMove} ontouchmove={handleTouchMove} />

{#if enabled}
	<div
		class="pointer-events-none fixed z-[9999999] left-0 top-0 w-3 h-3 rounded-full"
		style="left: {coords.x}px; top: {coords.y}px; background: {cursorColors.primary};"
	></div>
	<div
		class="pointer-events-none fixed z-[9999998] w-8 h-8 rounded-full -translate-x-1/2 -translate-y-1/2"
		style="left: {trail.x}px; top: {trail.y}px; background: {cursorColors.trail}; filter: blur(12px);"
	></div>
{/if}
