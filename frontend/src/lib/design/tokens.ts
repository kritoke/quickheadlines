export const spacing = {
	compact: '8px',
	default: '12px',
	spacious: '16px',
	horizontal: {
		compact: '8px',
		default: '12px',
		spacious: '16px'
	}
} as const;

export const typography = {
	scale: {
		headline: 'text-xl font-bold',
		body: 'text-base',
		auxiliary: 'text-sm',
		action: 'text-xs font-medium'
	} as const,
	sizes: {
		headline: '1.25rem',
		body: '1rem',
		auxiliary: '0.875rem',
		action: '0.75rem'
	} as const,
	weights: {
		normal: '400',
		medium: '500',
		semibold: '600',
		bold: '700'
	} as const
} as const;

export const elevation = {
	none: 'none',
	low: '0 1px 2px rgba(0, 0, 0, 0.05)',
	medium: '0 4px 12px var(--theme-shadow, rgba(59, 130, 246, 0.15))',
	high: '0 8px 24px var(--theme-shadow, rgba(59, 130, 246, 0.2))'
} as const;

export const semantic = {
	card: 'theme-card rounded-lg border',
	header: 'theme-header rounded-lg border',
	button: 'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors',
	input: 'w-full px-4 py-3 text-base rounded-lg border theme-bg-secondary theme-border focus:outline-none focus:ring-2 focus:ring-blue-500'
} as const;
