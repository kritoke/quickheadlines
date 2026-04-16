import { SvelteSet } from 'svelte/reactivity';

type NavigationState = {
	scrollPositions: Map<string, number>;
	visitedRoutes: Set<string>;
	currentPath: string;
};

const state = $state<NavigationState>({
	scrollPositions: new Map(),
	visitedRoutes: new SvelteSet<string>(),
	currentPath: ''
});

function getFallbackScrollY(): number {
	return window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0;
}

function withScrollContainer(callback: (container: Window | HTMLElement) => void, fallback: () => void): void {
	if (typeof window === 'undefined') return;
	try {
		import('$lib/utils/scroll').then(({ getScrollContainer }) => {
			try {
				callback(getScrollContainer());
			} catch {
				fallback();
			}
		}).catch(() => {
			fallback();
		});
	} catch {
		fallback();
	}
}

export function saveScroll(path: string): void {
	withScrollContainer(
		(container) => {
			const top = (container === window)
				? getFallbackScrollY()
				: ((container as HTMLElement).scrollTop || 0);
			state.scrollPositions.set(path, top);
		},
		() => { state.scrollPositions.set(path, getFallbackScrollY()); }
	);
}

export function getScroll(path: string): number | undefined {
	return state.scrollPositions.get(path);
}

export function hasVisited(path: string): boolean {
	return state.visitedRoutes.has(path);
}

export function markVisited(path: string): void {
	state.visitedRoutes.add(path);
}

export function setCurrentPath(path: string): void {
	state.currentPath = path;
}

export function getCurrentPath(): string {
	return state.currentPath;
}

export function resetScroll(): void {
	const resetWindow = () => {
		window.scrollTo(0, 0);
		document.documentElement.scrollTop = 0;
		document.body.scrollTop = 0;
		const app = document.getElementById('app');
		if (app) app.scrollTop = 0;
	};

	withScrollContainer(
		(container) => {
			if (container === window) {
				resetWindow();
			} else {
				try { (container as HTMLElement).scrollTo({ top: 0, behavior: 'auto' }); }
				catch { (container as HTMLElement).scrollTop = 0; }
			}
		},
		resetWindow
	);
}

export function scrollToPosition(y: number): void {
	const scrollToY = (targetY: number) => {
		window.scrollTo({ top: targetY, behavior: 'auto' });
		document.documentElement.scrollTop = targetY;
		document.body.scrollTop = targetY;
	};

	withScrollContainer(
		(container) => {
			if (container === window) {
				scrollToY(y);
			} else {
				try { (container as HTMLElement).scrollTo({ top: y, behavior: 'auto' }); }
				catch { (container as HTMLElement).scrollTop = y; }
			}
		},
		() => scrollToY(y)
	);
}
