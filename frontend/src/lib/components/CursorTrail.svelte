<script lang="ts">
	import { Spring } from 'svelte/motion';
	import { themeState } from '$lib/stores/theme.svelte';

	let enabled = $derived(themeState.cursorTrail && themeState.mounted);

	const primarySpring = new Spring({ x: 0, y: 0 }, {
		stiffness: 0.15,
		damping: 0.8
	});

	const auraSpring = new Spring({ x: 0, y: 0 }, {
		stiffness: 0.08,
		damping: 0.7
	});

	function handleMouseMove(e: MouseEvent) {
		primarySpring.set({ x: e.clientX, y: e.clientY });
		auraSpring.set({ x: e.clientX, y: e.clientY });
	}

	$effect(() => {
		if (enabled) {
			window.addEventListener('mousemove', handleMouseMove);
			return () => window.removeEventListener('mousemove', handleMouseMove);
		}
	});
</script>

{#if enabled}
	<div
		class="fixed inset-0 pointer-events-none z-[9999]"
		aria-hidden="true"
	>
		<div
			class="absolute w-20 h-20 rounded-full"
			style="
				left: {$auraSpring.x - 40}px;
				top: {$auraSpring.y - 40}px;
				background: rgba(150, 173, 141, 0.3);
				filter: blur(12px);
			"
		></div>

		<div
			class="absolute w-4 h-4 rounded-full"
			style="
				left: {$primarySpring.x - 8}px;
				top: {$primarySpring.y - 8}px;
				background: #96ad8d;
			"
		></div>
	</div>
{/if}
