<script lang="ts">
	import '../app.css';
	import { themeState, initTheme } from '$lib/stores/theme.svelte';
	import { initLayout } from '$lib/stores/layout.svelte';
	import { isIOS } from '$lib/utils/theme';
	import { onNavigate } from '$app/navigation';
	import {
		saveScroll,
		getScroll,
		hasVisited,
		markVisited,
		scrollToPosition,
		resetScroll
	} from '$lib/stores/navigation.svelte';
	import Effects from '$lib/components/Effects.svelte';
	import CrystalBadge from '$lib/components/CrystalBadge.svelte';
	import ScrollToTop from '$lib/components/ScrollToTop.svelte';
	import ToastContainer from '$lib/components/ToastContainer.svelte';
	
	let { children } = $props();
	
	onNavigate((navigation) => {
		if (!navigation.to) return;
		
		const toPath = navigation.to.url.pathname;
		
		if (navigation.type === 'popstate') {
			const savedScroll = getScroll(toPath);
			if (savedScroll !== undefined) {
				navigation.complete.then(() => scrollToPosition(savedScroll));
			}
		} else {
			navigation.complete.then(() => {
				document.documentElement.scrollTop = 0;
				document.body.scrollTop = 0;
				window.scrollTo(0, 0);
			});
		}
		
		markVisited(toPath);
		
		if (!navigation.from || !navigation.complete) return;
		
		const fromPath = navigation.from.url.pathname;
		if (navigation.type !== 'popstate') {
			saveScroll(fromPath);
		}
	});
	
	$effect(() => {
		if (typeof window !== 'undefined' && isIOS()) {
			document.documentElement.classList.add('ios-device');
		}
		
		initTheme();
		initLayout();
	});
</script>

<Effects />
<div id="app" class="min-h-screen theme-bg-primary theme-text-primary transition-colors duration-200" data-name="app-layout">
	{@render children()}
	<div class="pb-4 flex justify-center">
		<CrystalBadge />
	</div>
</div>
<ScrollToTop />
<ToastContainer />
