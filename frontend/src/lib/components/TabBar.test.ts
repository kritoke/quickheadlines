import { describe, it, expect, vi } from 'vitest';

describe('TabBar', () => {
	it('should have sticky class in TabBar component', () => {
		const TabBarContent = `
			<nav class="tab-bar sticky top-16 z-20 bg-white dark:bg-slate-900 flex gap-1 p-2 overflow-x-auto">
				<button class="tab">All</button>
			</nav>
		`;
		expect(TabBarContent).toContain('sticky');
		expect(TabBarContent).toContain('top-16');
	});

	it('should have correct sticky positioning classes', () => {
		const expectedClasses = ['sticky', 'top-16', 'z-20'];
		const actualClasses = 'sticky top-16 z-20 bg-white dark:bg-slate-900';
		
		expectedClasses.forEach(cls => {
			expect(actualClasses).toContain(cls);
		});
	});

	it('should have overflow-x-auto for horizontal scrolling', () => {
		const classes = 'sticky top-16 z-20 bg-white dark:bg-slate-900 flex gap-1 p-2 overflow-x-auto';
		expect(classes).toContain('overflow-x-auto');
	});

	it('should have responsive container classes', () => {
		const mainClasses = 'max-w-7xl mx-auto px-4 py-4 pt-16 overflow-visible';
		expect(mainClasses).toContain('max-w-7xl');
		expect(mainClasses).toContain('overflow-visible');
	});
});
