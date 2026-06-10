export type ScrollTarget = Window | HTMLElement;

export function getScrollContainer(): ScrollTarget {
	if (typeof window === 'undefined') return window;

	const app = document.getElementById('app');

	try {
		if (app) {
			const style = window.getComputedStyle(app);
			const overflowY = style.overflowY;
			const isScrollable = (overflowY === 'auto' || overflowY === 'scroll');
			if (isScrollable && app.scrollHeight > app.clientHeight) return app;

			// Layout uses flex column with overflow:hidden on #app;
			// the actual scroll container is the first scrollable child (typically <main>)
			// the actual scroll container is the first scrollable child (typically <main>)
			for (const child of app.children) {
				const childStyle = window.getComputedStyle(child as Element);
				const childOverflow = childStyle.overflowY;
				if ((childOverflow === 'auto' || childOverflow === 'scroll') && (child as HTMLElement).scrollHeight > (child as HTMLElement).clientHeight) {
					return child as HTMLElement;
				}
			}
		}
	} catch (_e) {
		// DOM access may fail in SSR or restricted contexts
	}

	return window;
}

export function getScrollTop(container: ScrollTarget): number {
	if (container === window) {
		return window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0;
	}
	return (container as HTMLElement).scrollTop || 0;
}

export function scrollToPosition(y: number, container?: ScrollTarget): void {
	if (typeof window === 'undefined') return;

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