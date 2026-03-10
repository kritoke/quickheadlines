import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushSync, mount, unmount } from 'svelte';
import AppHeader from './AppHeader.svelte';
import type { Snippet } from 'svelte';

describe('AppHeader', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	afterEach(() => {
		vi.clearAllMocks();
	});

	it('renders title', () => {
		const component = mount(AppHeader, {
			target: document.body,
			props: {
				title: 'My App Title',
				viewLink: { href: '/timeline', icon: 'clock' },
				searchExpanded: false,
				onSearchToggle: vi.fn()
			}
		});
		
		expect(document.body.textContent).toContain('My App Title');
		
		unmount(component);
	});

	it('renders logo button with clock icon URL', () => {
		const component = mount(AppHeader, {
			target: document.body,
			props: {
				title: 'Test',
				viewLink: { href: '/timeline', icon: 'clock' },
				searchExpanded: false,
				onSearchToggle: vi.fn()
			}
		});
		
		const logoButton = document.body.querySelector('button');
		expect(logoButton).toBeInTheDocument();
		
		unmount(component);
	});

	it('renders logo button with rss icon URL', () => {
		const component = mount(AppHeader, {
			target: document.body,
			props: {
				title: 'Test',
				viewLink: { href: '/', icon: 'rss' },
				searchExpanded: false,
				onSearchToggle: vi.fn()
			}
		});
		
		const logoButton = document.body.querySelector('button');
		expect(logoButton).toBeInTheDocument();
		
		unmount(component);
	});

	it('calls onSearchToggle when search button clicked', () => {
		const onSearchToggle = vi.fn();
		
		const component = mount(AppHeader, {
			target: document.body,
			props: {
				title: 'Test',
				viewLink: { href: '/', icon: 'rss' },
				searchExpanded: false,
				onSearchToggle
			}
		});
		
		const searchButton = document.body.querySelector('button[aria-label="Search"]');
		searchButton?.click();
		flushSync();
		
		expect(onSearchToggle).toHaveBeenCalledTimes(1);
		
		unmount(component);
	});

	it('renders ThemePicker component', () => {
		const component = mount(AppHeader, {
			target: document.body,
			props: {
				title: 'Test',
				viewLink: { href: '/', icon: 'rss' },
				searchExpanded: false,
				onSearchToggle: vi.fn()
			}
		});
		
		const themeButton = document.body.querySelector('button[title="Theme"]');
		expect(themeButton).toBeInTheDocument();
		
		unmount(component);
	});
});
