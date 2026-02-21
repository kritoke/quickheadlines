<script lang="ts">
	import { onMount } from 'svelte';
	import { themeState } from '$lib/stores/theme.svelte';

	onMount(() => {
		function updateCursor(e: MouseEvent) {
			document.documentElement.style.setProperty('--cursor-x', e.clientX + 'px');
			document.documentElement.style.setProperty('--cursor-y', e.clientY + 'px');
		}

		document.addEventListener('mousemove', updateCursor, { passive: true });
		return () => document.removeEventListener('mousemove', updateCursor);
	});
</script>

{#if themeState.coolMode}
	<style>
		:root {
			--cursor-x: -100px;
			--cursor-y: -100px;
		}
	</style>
	<div class="fixed inset-0 pointer-events-none z-[9999]" aria-hidden="true">
		<div
			class="absolute w-20 h-20 rounded-full"
			style="
				left: calc(var(--cursor-x) - 40px);
				top: calc(var(--cursor-y) - 40px);
				background: rgba(150, 173, 141, 0.3);
				filter: blur(12px);
			"
		></div>
		<div
			class="absolute w-4 h-4 rounded-full"
			style="
				left: calc(var(--cursor-x) - 8px);
				top: calc(var(--cursor-y) - 8px);
				background: #96ad8d;
			"
		></div>
	</div>
{/if}
