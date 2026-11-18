import { getScrollContainer, getScrollTop } from "#lib/utils/scroll";

/** Per-path scroll positions, restored on back/forward navigation. */
const scrollPositions = new Map<string, number>();

export function saveScroll(path: string): void {
	if (typeof window === "undefined") return;
	try {
		const container = getScrollContainer();
		const top =
			container === window
				? getScrollTop(window)
				: (container as HTMLElement).scrollTop || 0;
		scrollPositions.set(path, top);
	} catch {
		scrollPositions.set(path, getScrollTop(window));
	}
}

export function getScroll(path: string): number | undefined {
	return scrollPositions.get(path);
}
