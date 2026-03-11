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
		if (!navigation.from || !navigation.to) return;
		
		const fromPath = navigation.from.url.pathname;
		const toPath = navigation.to.url.pathname;
		
		if (navigation.type === 'enter' || navigation.type === 'goto') {
			markVisited(toPath);
			return;
		}
		
		saveScroll(fromPath);
		markVisited(toPath);
		
		if (!navigation.complete) {
			navigation.complete.then(() => {
				const savedScroll = getScroll(toPath);
				if (savedScroll !== undefined) {
					scrollToPosition(savedScroll);
				} else {
					resetScroll();
				}
			});
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
<div id="app" class="min-h-screen bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 transition-colors duration-200" data-name="app-layout">
	{@render children()}
	<div class="pb-4 flex justify-center">
		<CrystalBadge />
	</div>
</div>
<ScrollToTop />
<ToastContainer />
