export type ThemeId = string;

const SKELETON_PRESETS = ['catppuccin','cerberus','concord','crimson','fennec','hamlindigo','legacy','mint','modern','mona','nosh','nouveau','pine','reign','rocket','rose','sahara','seafoam','terminus','vintage','vox','wintry'] as const;
const NOVELTY_THEMES = ['matrix','hotdog'] as const;
const CUSTOM_DARK_THEMES = ['matrix','hotdog'] as const;

const LEGACY_THEME_MAP: Record<string, string> = {
	light: 'modern',
	dark: 'modern',
	retro: 'modern',
	ocean: 'modern',
	sunset: 'modern',
	dracula: 'modern',
	cyberpunk: 'modern',
	forest: 'modern'
};

export const ALL_THEMES = [...SKELETON_PRESETS, ...NOVELTY_THEMES] as const;
export type AllTheme = typeof ALL_THEMES[number];

export const NOVELTY_THEME_IDS = NOVELTY_THEMES;
export type NoveltyThemeId = typeof NOVELTY_THEMES[number];

export function isSkeletonPreset(theme: string): boolean {
	return (SKELETON_PRESETS as readonly string[]).includes(theme);
}

export function isNoveltyTheme(theme: string): boolean {
	return (NOVELTY_THEMES as readonly string[]).includes(theme);
}

export function isCustomDarkTheme(theme: string): boolean {
	return (CUSTOM_DARK_THEMES as readonly string[]).includes(theme);
}

export function isDarkTheme(): boolean {
	return document.documentElement.classList.contains('dark');
}

export const themeStyles = ALL_THEMES.map(id => ({ id, name: id, description: `Skeleton ${id} theme` }));

export function getThemePreview(_theme: string): string {
	return 'linear-gradient(135deg, var(--color-surface-50) 50%, var(--color-surface-500) 50%)';
}

export function getThemeAccentColors() {
	return { bg: '', bgSecondary: '', text: '', border: '', accent: '', shadow: '' };
}

export function getDotIndicatorColors(): string {
	return 'var(--color-primary-500, #94a3b8)';
}

export const themeState = $state({
	theme: 'modern' as ThemeId,
	effects: true,
	mounted: false
});

export function getThemeColors(): { primary: string; surface: string; contrast: string } {
	const style = getComputedStyle(document.documentElement);
	return {
		primary: style.getPropertyValue('--color-primary-500').trim() || '#3b82f6',
		surface: style.getPropertyValue('--color-surface-50').trim() || '#ffffff',
		contrast: style.getPropertyValue('--color-surface-contrast-light').trim() || '#000000'
	};
}

export function getCursorColors(): { primary: string; trail: string } {
	const style = getComputedStyle(document.documentElement);
	const primary = style.getPropertyValue('--color-primary-500').trim() || '#64748b';
	return {
		primary,
		trail: primary + '4D'
	};
}

export function getAccentColor(): string {
	const style = getComputedStyle(document.documentElement);
	return style.getPropertyValue('--color-primary-500').trim() || '#3b82f6';
}

export function getScrollButtonColors(): { bg: string; text: string; hover: string } {
	const style = getComputedStyle(document.documentElement);
	const primary = style.getPropertyValue('--color-primary-500').trim() || '#334155';
	const primary600 = style.getPropertyValue('--color-primary-600').trim() || '#475569';
	return {
		bg: primary,
		text: '#ffffff',
		hover: primary600
	};
}

export function initTheme() {
	if (typeof window === 'undefined') return;

	try {
		let savedTheme = localStorage.getItem('quickheadlines-theme') || 'modern';

		if (LEGACY_THEME_MAP[savedTheme]) {
			savedTheme = LEGACY_THEME_MAP[savedTheme];
			localStorage.setItem('quickheadlines-theme', savedTheme);
		}

		if (!ALL_THEMES.includes(savedTheme as AllTheme)) {
			savedTheme = 'modern';
		}

		themeState.theme = savedTheme;
		applyTheme(savedTheme);

		const savedEffects = localStorage.getItem('quickheadlines-effects');
		const savedCoolMode = localStorage.getItem('quickheadlines-coolmode');
		themeState.effects = savedEffects !== 'false' && savedCoolMode !== 'false';
	} catch {
		themeState.theme = 'modern';
		applyTheme('modern');
	}

	themeState.mounted = true;
}

export function applyTheme(theme: ThemeId) {
	document.documentElement.setAttribute('data-theme', theme);

	const isCustomDark = isCustomDarkTheme(theme);
	document.documentElement.classList.toggle('dark', isCustomDark);
}

export function setTheme(theme: ThemeId) {
	themeState.theme = theme;
	applyTheme(theme);
	try {
		localStorage.setItem('quickheadlines-theme', theme);
	} catch {
		// localStorage not available (private browsing)
	}
}

export function toggleTheme() {
	const isDark = document.documentElement.classList.contains('dark');
	if (isDark) {
		document.documentElement.classList.remove('dark');
	} else {
		document.documentElement.classList.add('dark');
	}
}

export function toggleEffects() {
	themeState.effects = !themeState.effects;
	try {
		localStorage.setItem('quickheadlines-effects', String(themeState.effects));
	} catch {
		// localStorage not available
	}
}
