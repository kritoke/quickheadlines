import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushSync, mount, unmount } from 'svelte';
import ThemePicker from './ThemePicker.svelte';
import { themeState, setTheme } from '$lib/stores/theme.svelte';

describe('ThemePicker', () => {
	let cleanup: (() => void) | undefined;

	beforeEach(() => {
		themeState.theme = 'light';
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
		themeState.theme = 'light';
		themeState.effects = false;
	});

	it('renders theme button', () => {
		const component = mount(ThemePicker, {
			target: document.body
		});
		
		const button = document.body.querySelector('button[title="Theme"]');
		expect(button).toBeInTheDocument();
		
		unmount(component);
	});

	it('opens dropdown on button click', () => {
		const component = mount(ThemePicker, {
			target: document.body
		});
		
		const button = document.body.querySelector('button');
		button?.click();
		flushSync();
		
		expect(document.body.textContent).toContain('Theme');
		expect(document.body.textContent).toContain('Light');
		expect(document.body.textContent).toContain('Dark');
		
		unmount(component);
	});

	it('displays all theme options when dropdown is open', () => {
		const component = mount(ThemePicker, {
			target: document.body
		});
		
		const button = document.body.querySelector('button');
		button?.click();
		flushSync();
		
		expect(document.body.textContent).toContain('Retro 80s');
		expect(document.body.textContent).toContain('Matrix');
		expect(document.body.textContent).toContain('Ocean');
		
		unmount(component);
	});
});
