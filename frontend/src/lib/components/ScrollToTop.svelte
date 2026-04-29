<script lang="ts">
	import { getScrollContainer, getScrollTop } from '$lib/utils/scroll';
	
	let isMobile = $state(false);
	let visible = $state(true);

	$effect(() => {
		if (typeof window === 'undefined') return;
		isMobile = window.innerWidth < 768;
		const handleResize = () => (isMobile = window.innerWidth < 768);
		window.addEventListener('resize', handleResize);
		return () => window.removeEventListener('resize', handleResize);
	});

	$effect(() => {
		if (typeof window === 'undefined') return;

		function checkScroll() {
			const c = getScrollContainer();
			const top = getScrollTop(c);
			visible = top < 100 ? false : true;
		}

		checkScroll();
		window.addEventListener('scroll', checkScroll, { passive: true });
		const app = document.getElementById('app');
		if (app) app.addEventListener('scroll', checkScroll, { passive: true });
		return () => {
			window.removeEventListener('scroll', checkScroll);
			if (app) app.removeEventListener('scroll', checkScroll);
		};
	});

	function doScroll(e: Event) {
		e.preventDefault();
		e.stopPropagation();
		const c = getScrollContainer();
		if (c === window) {
			window.scrollTo(0, 0);
			document.documentElement.scrollTop = 0;
			document.body.scrollTop = 0;
		} else {
			(c as HTMLElement).scrollTop = 0;
		}
	}
</script>

<button
	type="button"
	class="scroll-btn"
	class:mobile={isMobile}
	style="background-color: var(--color-primary-500, #334155); color: #ffffff; z-index: 999999;"
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
		right: 1rem;
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
		transition: bottom 0.2s ease;
		-webkit-tap-highlight-color: transparent;
		touch-action: manipulation;
	}
	
	.scroll-btn.mobile {
		bottom: 5rem;
	}
	
	@media (min-width: 640px) {
		.scroll-btn {
			right: max(1rem, calc((100vw - 1400px) / 2 + 0.75rem));
		}
	}
	
	.scroll-btn:hover {
		filter: brightness(1.1);
	}
	
	.scroll-btn:active {
		transform: scale(0.95);
	}
</style>
