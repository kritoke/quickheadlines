<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState, getCursorColors } from '$lib/stores/theme.svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	let cursorColors = $derived(getCursorColors(themeState.theme));
	let enabled = $derived(themeState.mounted && themeState.effects);

	function handleMouseMove(e: MouseEvent) {
		if (!enabled) return;
		coords.set({ x: e.clientX, y: e.clientY });
		setTimeout(() => trail.set({ x: e.clientX, y: e.clientY }), 50);
	}

	function handleTouchMove(e: TouchEvent) {
		if (!enabled || e.touches.length === 0) return;
		const touch = e.touches[0];
		coords.set({ x: touch.clientX, y: touch.clientY });
		setTimeout(() => trail.set({ x: touch.clientX, y: touch.clientY }), 50);
	}
</script>

<svelte:window onmousemove={handleMouseMove} ontouchmove={handleTouchMove} />

{#if enabled}
	<div
		class="pointer-events-none fixed z-[9999999] w-3 h-3 rounded-full"
		style="left: {$coords.x}px; top: {$coords.y}px; background: {cursorColors.primary};"
	></div>
	<div
		class="pointer-events-none fixed z-[9999998] w-8 h-8 rounded-full"
		style="left: {$trail.x - 16}px; top: {$trail.y - 16}px; background: {cursorColors.trail}; filter: blur(12px);"
	></div>
{/if}
