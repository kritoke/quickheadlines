import { describe, it, expect, vi } from 'vitest';
import { createUrlTabChecker, resolveTab } from './urlTab';

describe('resolveTab', () => {
	it('prefers the URL tab', () => {
		expect(resolveTab('tech', 'all')).toBe('tech');
	});

	it('falls back to the stored tab when the URL has none or an empty one', () => {
		expect(resolveTab(null, 'security')).toBe('security');
		expect(resolveTab(undefined, 'security')).toBe('security');
		expect(resolveTab('', 'security')).toBe('security');
	});
});

describe('createUrlTabChecker', () => {
	it('skips the initial run even if the tab differs', () => {
		const onChange = vi.fn();
		const check = createUrlTabChecker(() => 'all', onChange);
		check('tech');
		expect(onChange).not.toHaveBeenCalled();
	});

	it('calls onChange on later runs when the URL tab differs', () => {
		const onChange = vi.fn();
		let current = 'all';
		const check = createUrlTabChecker(() => current, onChange);
		check('all');
		check('tech');
		expect(onChange).toHaveBeenCalledWith('tech');
		current = 'tech';
		check('tech');
		expect(onChange).toHaveBeenCalledTimes(1);
	});

	it('reloads an empty tab when navigated to again (no length-based gate)', () => {
		const onChange = vi.fn();
		const check = createUrlTabChecker(() => 'empty-tab', onChange);
		check('empty-tab');
		check('other');
		expect(onChange).toHaveBeenCalledWith('other');
	});
});
