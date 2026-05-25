/**
 * Grid system with responsive breakpoints
 * Use these instead of magic numbers for column counts
 */

/**
 * Breakpoint definitions matching Tailwind defaults
 */
export const breakpoints = {
	base: '0px', // Mobile first
	sm: '640px',
	md: '768px',
	lg: '1024px',
	xl: '1280px',
	'2xl': '1536px',
} as const;

export type BreakpointKey = keyof typeof breakpoints;

/**
 * Grid column configurations
 * Each entry defines responsive column counts
 */
export const gridColumns = {
	1: { base: 1 },
	2: { base: 1, sm: 2 },
	3: { base: 1, sm: 2, lg: 3 },
	4: { base: 1, sm: 2, lg: 3, xl: 4 },
	5: { base: 1, sm: 2, lg: 3, xl: 5 },
	6: { base: 1, sm: 2, lg: 4, xl: 6 },
} as const;

export type GridColumnsKey = keyof typeof gridColumns;

/**
 * Generate Tailwind grid classes from column configuration
 * Example: getGridClass(3) → "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
 */
export function getGridClass(columns: GridColumnsKey): string {
	const config = gridColumns[columns];
	return Object.entries(config)
		.map(([breakpoint, cols]) => {
			return breakpoint === 'base' ? `grid-cols-${cols}` : `${breakpoint}:grid-cols-${cols}`;
		})
		.join(' ');
}

/**
 * Generate gap classes for consistent spacing in grids
 */
export const gap = {
	none: 'gap-0',
	xs: 'gap-1',
	sm: 'gap-2',
	md: 'gap-3 sm:gap-4',
	lg: 'gap-4 sm:gap-5 md:gap-6',
	xl: 'gap-6 sm:gap-8 md:gap-10',
} as const;

export type GapKey = keyof typeof gap;

/**
 * Get gap class string
 */
export function getGapClass(gapKey: GapKey): string {
	return gap[gapKey];
}
