<script lang="ts">
	import { onMount } from 'svelte';
	import { themeState } from '$lib/stores/theme.svelte';

	let container: HTMLDivElement;

	onMount(() => {
		if (!container) return;

		function handleMouseMove(e: MouseEvent) {
			const aura = container.querySelector('.cursor-aura') as HTMLElement;
			const dot = container.querySelector('.cursor-dot') as HTMLElement;
			
			if (aura) {
				aura.style.left = (e.clientX - 40) + 'px';
				aura.style.top = (e.clientY - 40) + 'px';
			}
			if (dot) {
				dot.style.left = (e.clientX - 8) + 'px';
				dot.style.top = (e.clientY - 8) + 'px';
			}
		}

		window.addEventListener('mousemove', handleMouseMove);
		return () => window.removeEventListener('mousemove', handleMouseMove);
	});
</script>

{#if themeState.coolMode}
	<div
		bind:this={container}
		class="fixed inset-0 pointer-events-none z-[9999]"
		aria-hidden="true"
	>
		<div
			class="cursor-aura absolute w-20 h-20 rounded-full"
			style="left: -100px; top: -100px; background: rgba(150, 173, 141, 0.3); filter: blur(12px);"
		></div>
		<div
			class="cursor-dot absolute w-4 h-4 rounded-full"
			style="left: -100px; top: -100px; background: #96ad8d;"
		></div>
	</div>
{/if}
