export type ScrollTarget = Window | HTMLElement;

export function getScrollContainer(): ScrollTarget {
	if (typeof window === "undefined") return window;

	const app = document.getElementById("app");

	try {
		if (app) {
			const style = window.getComputedStyle(app);
			const overflowY = style.overflowY;
			const isScrollable = overflowY === "auto" || overflowY === "scroll";
			if (isScrollable && app.scrollHeight > app.clientHeight) return app;
		}
	} catch (_e) {
		// DOM access may fail in SSR or restricted contexts
	}

	return window;
}

export function getScrollTop(container: ScrollTarget): number {
	if (container === window) {
		return (
			window.scrollY ||
			document.documentElement.scrollTop ||
			document.body.scrollTop ||
			0
		);
	}
	return (container as HTMLElement).scrollTop || 0;
}

export function scrollToPosition(y: number, container?: ScrollTarget): void {
	if (typeof window === "undefined") return;

	const target = container || getScrollContainer();
	if (target === window) {
		window.scrollTo({ top: y });
		document.documentElement.scrollTop = y;
		document.body.scrollTop = y;
	} else {
		(target as HTMLElement).scrollTop = y;
	}
}

export function scrollToTop(container?: ScrollTarget): void {
	scrollToPosition(0, container);
}
