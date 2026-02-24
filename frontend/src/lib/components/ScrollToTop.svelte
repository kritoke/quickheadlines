<script lang="ts">
	import { themeState, getScrollButtonColors } from '$lib/stores/theme.svelte';
	
	let colors = $derived(getScrollButtonColors(themeState.theme));
	
	function doScroll(e: Event) {
		e.preventDefault();
		e.stopPropagation();
		
		document.documentElement.scrollTop = 0;
		document.body.scrollTop = 0;
		window.scrollTo(0, 0);
		
		document.body.scrollIntoView({ behavior: 'auto', block: 'start' });
		document.documentElement.scrollIntoView({ behavior: 'auto', block: 'start' });
		
		console.log('Scroll triggered!');
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
	<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
		<path d="M5 15l7-7 7 7"/>
	</svg>
	<span style="font-size: 0.6rem; font-weight: bold;">TOP</span>
</button>

<style>
	.scroll-btn {
		position: fixed;
		bottom: 2rem;
		right: 2rem;
		width: 3.5rem;
		height: 3.5rem;
		display: flex;
		flex-direction: column;
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
