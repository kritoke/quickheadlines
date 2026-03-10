<script lang="ts">
	import '../app.css';
	import { themeState, initTheme } from '$lib/stores/theme.svelte';
	import { initLayout } from '$lib/stores/layout.svelte';
	import Effects from '$lib/components/Effects.svelte';
	import CrystalBadge from '$lib/components/CrystalBadge.svelte';
	import ScrollToTop from '$lib/components/ScrollToTop.svelte';
	import ToastContainer from '$lib/components/ToastContainer.svelte';
	
	function isIOS(): boolean {
		if (typeof navigator === 'undefined') return false;
		return /iPad|iPhone|iPod/.test(navigator.userAgent);
	}
	
	let { children } = $props();
	
	$effect(() => {
		// Detect iOS and add class for CSS targeting
		if (typeof window !== 'undefined' && isIOS()) {
			document.documentElement.classList.add('ios-device');
		}
		
		initTheme();
		initLayout();
	});

	$effect(() => {
		if (typeof window === 'undefined') return;

		const handleNavigation = () => {
			requestAnimationFrame(() => {
				document.body.scrollTop = 0;
				document.documentElement.scrollTop = 0;
				window.scrollTo(0, 0);
			});
		};

		window.addEventListener('popstate', handleNavigation);
		window.addEventListener('pageshow', handleNavigation);

		return () => {
			window.removeEventListener('popstate', handleNavigation);
			window.removeEventListener('pageshow', handleNavigation);
		};
	});
</script>

<Effects />
<div id="app" class="min-h-screen bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 transition-colors duration-200" data-name="app-layout">
	{@render children()}
	<div class="pb-4 flex justify-center">
		<CrystalBadge />
	</div>
</div>
<ScrollToTop />
<ToastContainer />
