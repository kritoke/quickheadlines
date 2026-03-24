/**
 * Helper to determine the active scroll container at runtime.
 * Returns either `window` or the #app HTMLElement when that element
 * is being used as the scrollable container (common on iOS).
 */
export function getScrollContainer(): Window | HTMLElement {
  if (typeof window === 'undefined') return window as unknown as Window;

  const app = document.getElementById('app');

  try {
    if (app) {
      const style = window.getComputedStyle(app);
      const overflowY = style.overflowY;
      const isScrollable = (overflowY === 'auto' || overflowY === 'scroll');
      // If app actually scrolls (content taller than container) prefer it.
      if (isScrollable && app.scrollHeight > app.clientHeight) return app;
    }
  } catch (e) {
    // ignore and fallback to window
  }

  return window;
}

export function getScrollTop(container: Window | HTMLElement): number {
  if ((container as Window).scrollY !== undefined && (container as Window) === window) {
    return window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0;
  }

  return (container as HTMLElement).scrollTop || 0;
}

export function scrollToPosition(y: number, container?: Window | HTMLElement): void {
  if (typeof window === 'undefined') return;

  const target = container || getScrollContainer();
  if ((target as Window) === window) {
    window.scrollTo({ top: y, behavior: 'auto' });
    // keep fallback consistent
    document.documentElement.scrollTop = y;
    document.body.scrollTop = y;
  } else {
    try {
      (target as HTMLElement).scrollTo({ top: y, behavior: 'auto' });
    } catch (e) {
      (target as HTMLElement).scrollTop = y;
    }
  }
}

export function scrollToTop(container?: Window | HTMLElement): void {
  scrollToPosition(0, container);
}
