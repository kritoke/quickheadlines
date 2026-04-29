<script lang="ts">
	import { themeState } from '$lib/stores/theme.svelte';

	interface Props {
		class?: string;
		scrollContainer?: HTMLDivElement | undefined;
		onScroll?: () => void;
		children?: import('svelte').Snippet;
	}

	let { class: className = '', scrollContainer = $bindable(), onScroll, children }: Props = $props();

	let scrollRatio = $state(0);
	let thumbHeight = $state(20);
	let isVisible = $state(false);
	let hideTimeout: ReturnType<typeof setTimeout> | undefined;

	function handleScroll() {
		if (!scrollContainer) return;
		
		isVisible = true;
		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		scrollRatio = scrollTop / (scrollHeight - clientHeight);
		thumbHeight = Math.max((clientHeight / scrollHeight) * 100, 10);

		clearTimeout(hideTimeout);
		hideTimeout = setTimeout(() => (isVisible = false), 1500);
		
		onScroll?.();
	}

	$effect(() => {
		if (!scrollContainer) return;
		
		scrollContainer.addEventListener('scroll', handleScroll, { passive: true });
		handleScroll();
		
		return () => scrollContainer?.removeEventListener('scroll', handleScroll);
	});
</script>

<div class="relative h-full w-full {className}">
	<div
		bind:this={scrollContainer}
		class="absolute inset-0 overflow-y-auto overflow-x-hidden custom-scroll"
	>
		{@render children?.()}
	</div>

	<div 
		class="absolute right-1 top-2 bottom-2 w-1.5 transition-opacity duration-300 pointer-events-none"
		class:opacity-0={!isVisible}
		class:opacity-100={isVisible}
	>
		<div
			class="w-full rounded-full scrollbar-thumb"
			style:height="{thumbHeight}%"
			style:transform="translateY({scrollRatio * (100 - thumbHeight)}%)"
		></div>
	</div>
</div>

<style>
	.custom-scroll {
		-webkit-overflow-scrolling: touch;
	}

	:global(.custom-scroll::-webkit-scrollbar) { 
		display: none; 
	}

	:global(.custom-scroll) { 
		scrollbar-width: none; 
		-ms-overflow-style: none;
	}

	.scrollbar-thumb {
		background-color: var(--color-primary-500, #94a3b8);
	}
</style>
