import { SvelteSet } from 'svelte/reactivity';

type NavigationState = {
	scrollPositions: Map<string, number>;
	visitedRoutes: Set<string>;
	currentPath: string;
	feedsTab: string;
};

const state = $state<NavigationState>({
	scrollPositions: new Map(),
	visitedRoutes: new SvelteSet<string>(),
	currentPath: '',
	feedsTab: 'all'
});

export function saveScroll(path: string): void {
	if (typeof window === 'undefined') return;
	state.scrollPositions.set(path, window.scrollY);
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

export function setFeedsTab(tab: string): void {
	state.feedsTab = tab;
}

export function getFeedsTab(): string {
	return state.feedsTab;
}

export function resetScroll(): void {
	if (typeof window === 'undefined') return;
	window.scrollTo(0, 0);
}

export function scrollToPosition(y: number): void {
	if (typeof window === 'undefined') return;
	window.scrollTo({ top: y, behavior: 'auto' });
}
