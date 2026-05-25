/**
 * Border radius scale for consistent corner radii
 * Designed with Steve Jobs' attention to detail in mind
 */

export const radius = {
	none: '0',
	sm: '0.125rem', // 2px - very subtle rounding
	md: '0.5rem', // 8px - default for cards
	lg: '0.75rem', // 12px - large cards, buttons
	xl: '1rem', // 16px - modals, dialogs
	'2xl': '1.5rem', // 24px - large containers
	full: '9999px', // Pills, avatars, badges
} as const;

export type RadiusKey = keyof typeof radius;

/**
 * Generate CSS custom properties for radius
 */
export function radiusToCss(): Record<string, string> {
	const css: Record<string, string> = {};
	for (const [key, value] of Object.entries(radius)) {
		css[`--radius-${key}`] = value;
	}
	return css;
}

/**
 * Map Tailwind classes to radius tokens
 * Use these instead of raw Tailwind classes for consistency
 */
export const radiusClasses: Record<RadiusKey, string> = {
	none: 'rounded-none',
	sm: 'rounded-sm',
	md: 'rounded-md',
	lg: 'rounded-lg',
	xl: 'rounded-xl',
	'2xl': 'rounded-2xl',
	full: 'rounded-full',
};
