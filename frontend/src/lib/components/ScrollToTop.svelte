<script lang="ts">
  import { themeState, getScrollButtonColors } from '$lib/stores/theme.svelte';
  import { logger } from '$lib/utils/debug';
  
  let colors = $derived(getScrollButtonColors(themeState.theme));
	
	function doScroll(e: Event) {
		e.preventDefault();
		e.stopPropagation();
		
		document.documentElement.scrollTop = 0;
		document.body.scrollTop = 0;
		window.scrollTo(0, 0);
	}
</script>

<button
	type="button"
	class="scroll-btn"
	style="background-color: {colors.bg}; color: {colors.text}; z-index: 999999;"
	aria-label="Scroll to top"
	title="Back to top"
	onclick={doScroll}
>
	<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5">
		<path d="M5 15l7-7 7 7"/>
	</svg>
</button>

<style>
	.scroll-btn {
		position: fixed;
		bottom: 2rem;
		right: 2rem;
		width: 3rem;
		height: 3rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 9999px;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
		cursor: pointer;
		opacity: 1;
		visibility: visible;
		text-decoration: none;
		border: none;
		outline: none;
	}
	
	.scroll-btn:hover {
		filter: brightness(1.1);
	}
	
	.scroll-btn:active {
		transform: scale(0.95);
	}
</style>
