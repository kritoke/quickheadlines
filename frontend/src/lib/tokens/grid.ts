/**
 * Grid system with responsive breakpoints.
 *
 * IMPORTANT: All Tailwind class strings must be complete string literals in
 * source code. Tailwind scans source text and never evaluates JavaScript, so
 * dynamically constructed classes (`grid-cols-${n}`) are silently missing from
 * the compiled CSS. That bug previously broke the 4-column timeline layout
 * (`xl:grid-cols-4` was never generated and the grid fell back to 3 columns).
 */

/**
 * Timeline grid: multi-column only on large screens.
 * getGridClass(4) → "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
 */
const timelineGridClasses = {
 1: "grid-cols-1",
 2: "grid-cols-1 sm:grid-cols-2",
 3: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3",
 4: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4",
} as const;

/**
 * Feed grid: compact cards, so 4 columns kick in earlier (lg instead of xl).
 * getFeedGridClass(4) → "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4"
 */
const feedGridClasses = {
 1: "grid-cols-1",
 2: "grid-cols-1 sm:grid-cols-2",
 3: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3",
 4: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4",
} as const;

export type GridColumnsKey = keyof typeof timelineGridClasses;
export type FeedGridColumnsKey = keyof typeof feedGridClasses;

/** Timeline grid classes for the requested column count. */
export function getGridClass(columns: GridColumnsKey): string {
 return timelineGridClasses[columns];
}

/** Feed page grid classes for the requested column count. */
export function getFeedGridClass(columns: FeedGridColumnsKey): string {
 return feedGridClasses[columns];
}

/**
 * Gap classes for consistent spacing in grids
 */
export const gap = {
 none: "gap-0",
 xs: "gap-1",
 sm: "gap-2",
 md: "gap-3 sm:gap-4",
 lg: "gap-4 sm:gap-5 md:gap-6",
 xl: "gap-6 sm:gap-8 md:gap-10",
} as const;

export type GapKey = keyof typeof gap;

/**
 * Get gap class string
 */
export function getGapClass(gapKey: GapKey): string {
 return gap[gapKey];
}
