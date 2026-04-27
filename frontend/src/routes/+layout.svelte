<script lang="ts">
	import '../app.css';
	import { themeState, initTheme } from '$lib/stores/theme.svelte';
	import { initReadMode } from '$lib/stores/readMode.svelte';
	import { initLayout } from '$lib/stores/layout.svelte';
	import { isIOS } from '$lib/utils/theme';
	import { initBreakpoints } from '$lib/utils/breakpoint.svelte';
	import { onNavigate } from '$app/navigation';
	import type { Navigation } from '@sveltejs/kit';
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
	
	onNavigate((navigation: Navigation) => {
		if (!navigation.to) return;
		
		const toPath = navigation.to.url.pathname;
		
		if (navigation.type === 'popstate') {
			const savedScroll = getScroll(toPath);
			if (savedScroll !== undefined) {
				navigation.complete.then(() => scrollToPosition(savedScroll));
			}
		} else {
			navigation.complete.then(() => {
				resetScroll();
			});
		}
		
		markVisited(toPath);
		
		if (!navigation.from || !navigation.complete) return;
		
		const fromPath = navigation.from.url.pathname;
		if (navigation.type !== 'popstate') {
			saveScroll(fromPath);
		}
	});
	
	let layoutMounted = $state(false);

	$effect(() => {
		if (layoutMounted) return;
		layoutMounted = true;

		if (typeof window !== 'undefined' && isIOS()) {
			document.documentElement.classList.add('ios-device');
		}

		initTheme();
		initReadMode();
		initLayout();
		initBreakpoints();
	});
</script>

<Effects />
<div id="app" class="min-h-screen bg-white dark:bg-slate-950 text-slate-900 dark:text-slate-50 transition-colors duration-200" data-name="app-layout">
	{@render children()}
	<div class="pb-6 flex justify-center">
		<CrystalBadge />
	</div>
</div>
<ScrollToTop />
<ToastContainer />