/**
 * Shadow scale for consistent elevation
 * Each level serves a specific purpose
 */

export const shadows = {
	sm: '0 1px 2px 0 rgb(0 0 0 / 0.05)',
	md: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)',
	lg: '0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)',
	xl: '0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)',
	'2xl': '0 25px 50px -12px rgb(0 0 0 / 0.25)',
	inner: 'inset 0 2px 4px 0 rgb(0 0 0 / 0.05)',
} as const;

export type ShadowKey = keyof typeof shadows;

/**
 * Generate CSS custom properties for shadows
 */
export function shadowsToCss(): Record<string, string> {
	const css: Record<string, string> = {};
	for (const [key, value] of Object.entries(shadows)) {
		css[`--shadow-${key}`] = value;
	}
	return css;
}

/**
 * Map shadow keys to Tailwind classes
 */
export const shadowClasses: Record<ShadowKey, string> = {
	sm: 'shadow-sm',
	md: 'shadow-md',
	lg: 'shadow-lg',
	xl: 'shadow-xl',
	'2xl': 'shadow-2xl',
	inner: 'shadow-inner',
};
