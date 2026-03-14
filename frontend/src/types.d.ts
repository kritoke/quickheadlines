// Global types for testing
/// <reference types="vitest/globals" />
/// <reference types="svelte" />

interface Window {
  Element: typeof Element;
}

// Extend global scope with ResizeObserver
interface Global {
  ResizeObserver: typeof ResizeObserver;
}

declare const global: Global;