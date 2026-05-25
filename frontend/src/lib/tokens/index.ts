/**
 * Design Tokens
 * 
 * Centralized design decisions for consistent UI across the application.
 * These tokens serve as the single source of truth for:
 * - Spacing
 * - Border radius
 * - Shadows
 * - Grid system
 * 
 * Usage:
 * import { spacing, radius, getGridClass } from '$lib/tokens';
 */

export * from './spacing';
export * from './radius';
export * from './shadows';
export * from './grid';

import { spacing } from './spacing';
import { radius } from './radius';

/**
 * Generate all CSS custom properties from tokens
 * Add these to your root CSS or Tailwind config
 */
export function generateAllCssVars(): Record<string, string> {
	return {
		...spacingToCss(),
		...radiusToCss(),
		...shadowsToCss(),
	};
}

/**
 * Spacing aliases for common use cases
 * Use these for semantic meaning, not raw values
 */
export const semanticSpacing = {
	/** Inline element spacing */
	inline: spacing.sm,
	/** Between related items */
	related: spacing.md,
	/** Between sections */
	section: spacing.lg,
	/** Page-level spacing */
	page: spacing.xl,
	/** Card padding */
	cardPadding: spacing.md,
	/** Card gap in grids */
	cardGap: spacing.md,
} as const;

/**
 * Radius aliases for semantic use
 */
export const semanticRadius = {
	/** Subtle elements like badges */
	subtle: radius.sm,
	/** Default for cards and buttons */
	default: radius.md,
	/** Large interactive elements */
	large: radius.lg,
	/** Modal dialogs */
	modal: radius.xl,
	/** Pills and avatars */
	pill: radius.full,
} as const;
