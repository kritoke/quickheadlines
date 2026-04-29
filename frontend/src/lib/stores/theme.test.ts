import { describe, it, expect, vi, beforeEach } from 'vitest';
import { themeState, initTheme, toggleTheme, setTheme } from '../stores/theme.svelte';

const localStorageMock = (() => {
	let store: Record<string, string> = {};
	return {
		getItem: (key: string) => store[key] || null,
		setItem: (key: string, value: string) => { store[key] = value; },
		clear: () => { store = {}; }
	};
})();

Object.defineProperty(window, 'localStorage', { value: localStorageMock });

Object.defineProperty(window, 'matchMedia', {
	value: vi.fn().mockImplementation((query: string) => ({
		matches: false,
		media: query,
		addEventListener: vi.fn(),
		removeEventListener: vi.fn()
	}))
});

describe('Theme Store', () => {
	beforeEach(() => {
		localStorageMock.clear();
		document.documentElement.classList.remove('dark');
		document.documentElement.removeAttribute('data-theme');
		themeState.theme = 'modern';
		themeState.mounted = false;
	});

	it('initializes with modern theme by default', () => {
		initTheme();
		expect(themeState.theme).toBe('modern');
		expect(themeState.mounted).toBe(true);
	});

	it('loads saved theme from localStorage', () => {
		localStorageMock.setItem('quickheadlines-theme', 'catppuccin');
		initTheme();
		expect(themeState.theme).toBe('catppuccin');
	});

	it('migrates legacy themes to modern', () => {
		localStorageMock.setItem('quickheadlines-theme', 'dark');
		initTheme();
		expect(themeState.theme).toBe('modern');
		expect(localStorageMock.getItem('quickheadlines-theme')).toBe('modern');
	});

	it('setTheme persists to localStorage', () => {
		initTheme();
		setTheme('rose');
		expect(themeState.theme).toBe('rose');
		expect(localStorageMock.getItem('quickheadlines-theme')).toBe('rose');
	});

	it('toggleTheme toggles dark class', () => {
		initTheme();
		expect(document.documentElement.classList.contains('dark')).toBe(false);

		toggleTheme();
		expect(document.documentElement.classList.contains('dark')).toBe(true);

		toggleTheme();
		expect(document.documentElement.classList.contains('dark')).toBe(false);
	});
});
