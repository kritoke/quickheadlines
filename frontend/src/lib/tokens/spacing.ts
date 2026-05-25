/**
 * Spacing scale for consistent layout
 * Based on 4px grid system
 */

export const spacing = {
	xs: '0.25rem', // 4px
	sm: '0.5rem', // 8px
	md: '1rem', // 16px
	lg: '1.5rem', // 24px
	xl: '2rem', // 32px
	'2xl': '3rem', // 48px
	'3xl': '4rem', // 64px
	'4xl': '6rem', // 96px
} as const;

export type SpacingKey = keyof typeof spacing;

/**
 * Generate CSS custom properties for spacing
 */
export function spacingToCss(): Record<string, string> {
	const css: Record<string, string> = {};
	for (const [key, value] of Object.entries(spacing)) {
		css[`--spacing-${key}`] = value;
	}
	return css;
}
