/**
 * Tab-from-URL syncing shared by the feeds and timeline pages.
 *
 * Each page loads its initial tab itself in onMount, then reacts to later
 * `?tab=` changes. The checker skips its first invocation (the mount run,
 * already handled by onMount) and afterwards calls `onChange` only when the
 * URL tab differs from the tab the page currently shows.
 */
export function resolveTab(urlTab: string | null | undefined, storedTab: string): string {
	return urlTab || storedTab;
}

export function createUrlTabChecker(
	getCurrentTab: () => string,
	onChange: (tab: string) => void
): (urlTab: string) => void {
	let handledInitial = false;
	return (urlTab: string) => {
		if (!handledInitial) {
			handledInitial = true;
			return;
		}
		if (urlTab !== getCurrentTab()) {
			onChange(urlTab);
		}
	};
}
