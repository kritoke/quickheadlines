import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import { themeState, initTheme, toggleTheme } from '../stores/theme.svelte';

// Mock localStorage
const localStorageMock = (() => {
	let store: Record<string, string> = {};
	return {
		getItem: (key: string) => store[key] || null,
		setItem: (key: string, value: string) => { store[key] = value; },
		clear: () => { store = {}; }
	};
})();

Object.defineProperty(window, 'localStorage', { value: localStorageMock });

// Mock matchMedia
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
		themeState.theme = 'light';
		themeState.mounted = false;
	});

	it('initializes with light theme by default', () => {
		initTheme();
		expect(themeState.theme).toBe('light');
		expect(themeState.mounted).toBe(true);
	});

	it('loads saved theme from localStorage', () => {
		localStorageMock.setItem('quickheadlines-theme', 'dark');
		initTheme();
		expect(themeState.theme).toBe('dark');
		expect(document.documentElement.classList.contains('dark')).toBe(true);
	});

	it('toggleTheme switches between light and dark', () => {
		initTheme();
		expect(themeState.theme).toBe('light');
		
		toggleTheme();
		expect(themeState.theme).toBe('dark');
		expect(document.documentElement.classList.contains('dark')).toBe(true);
		
		toggleTheme();
		expect(themeState.theme).toBe('light');
		expect(document.documentElement.classList.contains('dark')).toBe(false);
	});

	it('persists theme to localStorage', () => {
		initTheme();
		toggleTheme();
		expect(localStorageMock.getItem('quickheadlines-theme')).toBe('dark');
	});
});
