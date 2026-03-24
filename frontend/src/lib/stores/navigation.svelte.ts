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

export function saveScroll(path: string): void {
  if (typeof window === 'undefined') return;
  // store scroll position for the active container
  try {
    import('$lib/utils/scroll').then(({ getScrollContainer }) => {
      try {
        const container = getScrollContainer();
        const top = (container === window)
          ? (window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0)
          : ((container as HTMLElement).scrollTop || 0);
        state.scrollPositions.set(path, top);
      } catch (e) {
        state.scrollPositions.set(path, window.scrollY);
      }
    }).catch(() => {
      state.scrollPositions.set(path, window.scrollY);
    });
  } catch (e) {
    state.scrollPositions.set(path, window.scrollY);
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
  if (typeof window === 'undefined') return;
  // Delegate to the scroll utility to pick the correct container
  try {
    import('$lib/utils/scroll').then(({ getScrollContainer }) => {
      try {
        const container = getScrollContainer();
        if (container === window) {
          window.scrollTo(0, 0);
          document.documentElement.scrollTop = 0;
          document.body.scrollTop = 0;
        } else {
          try { (container as HTMLElement).scrollTo({ top: 0, behavior: 'auto' }); }
          catch { (container as HTMLElement).scrollTop = 0; }
        }
      } catch (e) {
        window.scrollTo(0, 0);
        document.documentElement.scrollTop = 0;
        document.body.scrollTop = 0;
        const app = document.getElementById('app');
        if (app) app.scrollTop = 0;
      }
    }).catch(() => {
      window.scrollTo(0, 0);
      document.documentElement.scrollTop = 0;
      document.body.scrollTop = 0;
      const app = document.getElementById('app');
      if (app) app.scrollTop = 0;
    });
  } catch (e) {
    // fallback
    window.scrollTo(0, 0);
    document.documentElement.scrollTop = 0;
    document.body.scrollTop = 0;
    const app = document.getElementById('app');
    if (app) app.scrollTop = 0;
  }
}

export function scrollToPosition(y: number): void {
  if (typeof window === 'undefined') return;
  try {
    import('$lib/utils/scroll').then(({ getScrollContainer }) => {
      try {
        const container = getScrollContainer();
        if (container === window) {
          window.scrollTo({ top: y, behavior: 'auto' });
          document.documentElement.scrollTop = y;
          document.body.scrollTop = y;
        } else {
          try { (container as HTMLElement).scrollTo({ top: y, behavior: 'auto' }); }
          catch { (container as HTMLElement).scrollTop = y; }
        }
      } catch (e) {
        window.scrollTo({ top: y, behavior: 'auto' });
        document.documentElement.scrollTop = y;
        document.body.scrollTop = y;
      }
    }).catch(() => {
      window.scrollTo({ top: y, behavior: 'auto' });
      document.documentElement.scrollTop = y;
      document.body.scrollTop = y;
    });
  } catch (e) {
    window.scrollTo({ top: y, behavior: 'auto' });
    document.documentElement.scrollTop = y;
    document.body.scrollTop = y;
  }
}
