import { page } from '$app/state';
import { getStoredTab } from '#lib/stores/tabStore.svelte';
import { createUrlTabChecker, resolveTab } from './urlTab';

/** The tab requested by the current URL, falling back to the stored tab. */
export function currentUrlTab(): string {
	return resolveTab(page.url?.searchParams.get('tab'), getStoredTab());
}

/**
 * Call during component initialisation. Reacts to `?tab=` changes after the
 * initial mount (which the page handles in onMount).
 */
export function syncTabFromUrl(getCurrentTab: () => string, onChange: (tab: string) => void): void {
	const check = createUrlTabChecker(getCurrentTab, onChange);
	$effect(() => {
		check(currentUrlTab());
	});
}
