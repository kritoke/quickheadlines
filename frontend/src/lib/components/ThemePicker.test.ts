import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, unmount } from 'svelte';
import ThemePicker from './ThemePicker.svelte';
import { themeState, setTheme } from '$lib/stores/theme.svelte';

describe('ThemePicker', () => {
	let cleanup: (() => void) | undefined;

	beforeEach(() => {
		themeState.theme = 'modern';
		themeState.effects = false;
		themeState.mounted = true;
		vi.clearAllMocks();
	});

	afterEach(() => {
		if (cleanup) {
			unmount(cleanup as unknown as ReturnType<typeof mount>);
			cleanup = undefined;
		}
		vi.clearAllMocks();
		themeState.theme = 'modern';
		themeState.effects = false;
	});

	it('renders theme button with correct attributes', () => {
		const component = mount(ThemePicker, {
			target: document.body
		});

		const button = document.body.querySelector('button[title="Theme"]');
		expect(button).toBeInTheDocument();
		expect(button?.getAttribute('aria-haspopup')).toBe('dialog');
		expect(button?.getAttribute('data-state')).toBe('closed');

		unmount(component);
	});

	it('renders theme button with closed state', () => {
		const component = mount(ThemePicker, {
			target: document.body
		});

		const button = document.body.querySelector('button[title="Theme"]');
		expect(button).toBeInTheDocument();
		expect(button?.getAttribute('data-state')).toBe('closed');

		unmount(component);
	});

	it('displays color preview swatch for current theme', () => {
		const component = mount(ThemePicker, {
			target: document.body
		});

		const swatch = document.body.querySelector('button span[style]');
		expect(swatch).toBeInTheDocument();
		expect(swatch?.getAttribute('style')).toContain('background');

		unmount(component);
	});
});
