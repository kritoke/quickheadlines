import { SvelteSet } from 'svelte/reactivity';
import { getScrollContainer, getScrollTop, scrollToPosition as doScrollToPosition } from '$lib/utils/scroll';
import type { ScrollTarget } from '$lib/utils/scroll';

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

export function saveScroll(path: string): void {
	if (typeof window === 'undefined') return;
	try {
		const container = getScrollContainer();
		const top = container === window ? getScrollTop(window) : container.scrollTop || 0;
		state.scrollPositions.set(path, top);
	} catch {
		state.scrollPositions.set(path, getScrollTop(window));
	}
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
	doScrollToPosition(0);
}

export function scrollToPosition(y: number): void {
	doScrollToPosition(y);
}