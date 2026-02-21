<script lang="ts">
	import { onMount } from 'svelte';
	import { themeState } from '$lib/stores/theme.svelte';

	let container: HTMLDivElement;
	let aura: HTMLDivElement;
	let dot: HTMLDivElement;

	function updatePosition(e: MouseEvent) {
		if (aura) {
			aura.style.left = (e.clientX - 40) + 'px';
			aura.style.top = (e.clientY - 40) + 'px';
		}
		if (dot) {
			dot.style.left = (e.clientX - 8) + 'px';
			dot.style.top = (e.clientY - 8) + 'px';
		}
	}

	onMount(() => {
		document.addEventListener('mousemove', updatePosition);
		return () => document.removeEventListener('mousemove', updatePosition);
	});
</script>

{#if themeState.coolMode}
	<div
		bind:this={container}
		class="fixed inset-0 pointer-events-none z-[9999]"
		aria-hidden="true"
	>
		<div
			bind:this={aura}
			class="absolute w-20 h-20 rounded-full"
			style="left: -100px; top: -100px; background: rgba(150, 173, 141, 0.3); filter: blur(12px); will-change: left, top;"
		></div>
		<div
			bind:this={dot}
			class="absolute w-4 h-4 rounded-full"
			style="left: -100px; top: -100px; background: #96ad8d; will-change: left, top;"
		></div>
	</div>
{/if}
