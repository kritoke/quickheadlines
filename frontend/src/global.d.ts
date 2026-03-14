// Global types for testing and browser APIs
interface Element {
  click(): void;
  animate(keyframes: Keyframe[], options?: number | KeyframeAnimationOptions): Animation;
}

interface Window {
  Element: typeof Element;
}

declare const global: typeof globalThis & {
  fetch: typeof fetch;
  Element: typeof Element;
};