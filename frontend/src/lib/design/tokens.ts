export const spacing = {
	default: '16px',
	spacious: '24px',
	1: '4px',
	2: '8px',
	3: '12px',
	4: '16px',
	5: '20px',
	6: '24px',
	8: '32px',
	10: '40px',
	12: '48px',
	16: '64px',
	horizontal: {
		1: '4px',
		2: '8px',
		3: '12px',
		4: '16px',
		5: '20px',
		6: '24px',
		8: '32px'
	},
	vertical: {
		1: '4px',
		2: '8px',
		3: '12px',
		4: '16px',
		5: '20px',
		6: '24px',
		8: '32px'
	}
} as const;

export const typography = {
	scale: {
		xs: 'text-xs',
		sm: 'text-sm',
		base: 'text-base',
		lg: 'text-lg',
		xl: 'text-xl',
		'2xl': 'text-2xl',
		'3xl': 'text-3xl'
	} as const,
	sizes: {
		xs: '0.75rem',
		sm: '0.875rem',
		base: '1rem',
		lg: '1.125rem',
		xl: '1.25rem',
		'2xl': '1.5rem',
		'3xl': '1.875rem'
	} as const,
	weights: {
		normal: '400',
		medium: '500',
		semibold: '600',
		bold: '700'
	} as const,
	lineHeights: {
		tight: '1.25',
		normal: '1.5',
		relaxed: '1.625'
	}
} as const;

export const elevation = {
	none: 'none',
	low: '0 1px 2px rgba(0, 0, 0, 0.05)',
	medium: '0 4px 12px var(--theme-shadow, rgba(59, 130, 246, 0.15))',
	high: '0 8px 24px var(--theme-shadow, rgba(59, 130, 246, 0.2))'
} as const;

export const semantic = {
	card: 'rounded-xl border theme-card transition-shadow',
	header: 'rounded-xl border theme-header',
	button: 'inline-flex items-center justify-center rounded-lg text-sm font-medium transition-all duration-200',
	input: 'w-full px-4 py-3 text-base rounded-xl border theme-bg-secondary theme-border focus:outline-none focus:ring-2 focus:ring-blue-500 transition-shadow'
} as const;

export const zIndex = {
	base: 0,
	loadingBar: 20,
	header: 30,
	dropdown: 40,
	dialog: 50,
	sheet: 100,
	toast: 100,
	scrollToTop: 200,
	effects: 300,
} as const;

export const layout = {
	container: {
		maxWidth: '1400px',
		padding: '16px'
	},
	header: {
		height: '56px'
	}
} as const;