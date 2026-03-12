export type ThemeStyle = 'light' | 'dark' | 'retro' | 'matrix' | 'ocean' | 'sunset' | 'hotdog' | 'dracula' | 'cyberpunk' | 'forest';

export const customThemeIds = ['retro', 'matrix', 'ocean', 'sunset', 'hotdog', 'dracula', 'cyberpunk', 'forest'] as const;
export type CustomThemeId = typeof customThemeIds[number];

export const themeStyles: { id: ThemeStyle; name: string; description: string }[] = [
	{ id: 'light', name: 'Light', description: 'Clean light theme' },
	{ id: 'dark', name: 'Dark', description: 'Easy on the eyes' },
	{ id: 'retro', name: 'Retro', description: 'Neon synthwave vibes' },
	{ id: 'matrix', name: 'Matrix', description: 'Digital green rain' },
	{ id: 'ocean', name: 'Ocean', description: 'Deep blue waves' },
	{ id: 'sunset', name: 'Sunset', description: 'Warm amber tones' },
	{ id: 'hotdog', name: 'Hot Dog Stand', description: 'Windows 3.1 vibes' },
	{ id: 'dracula', name: 'Dracula', description: 'Popular purple dark' },
	{ id: 'cyberpunk', name: 'Cyberpunk', description: 'Neon magenta cyan' },
	{ id: 'forest', name: 'Forest', description: 'Earthy greens' }
];

export interface ThemeColors {
	bg: string;
	bgSecondary: string;
	text: string;
	border: string;
	accent: string;
	shadow: string;
	cursor: { primary: string; trail: string };
	scrollButton: { bg: string; text: string; hover: string };
	dotIndicator: string;
	preview: string;
	semantic: Record<string, string>;
}

export const themes: Record<ThemeStyle, ThemeColors> = {
	light: {
		bg: '#ffffff',
		bgSecondary: '#f1f5f9',
		text: '#0f172a',
		border: '#e2e8f0',
		accent: '#3b82f6',
		shadow: 'rgba(59, 130, 246, 0.15)',
		cursor: { primary: '#64748b', trail: 'rgba(100, 116, 139, 0.3)' },
		scrollButton: { bg: '#334155', text: '#ffffff', hover: '#475569' },
		dotIndicator: '#64748b',
		preview: 'linear-gradient(135deg, #ffffff 50%, #e2e8f0 50%)',
		semantic: {
			'--color-bg-primary': '#ffffff',
			'--color-bg-secondary': '#f1f5f9',
			'--color-text-primary': '#0f172a',
			'--color-text-secondary': '#64748b',
			'--color-border': '#e2e8f0',
			'--color-accent': '#3b82f6',
		}
	},
	dark: {
		bg: '#1e293b',
		bgSecondary: '#0f172a',
		text: '#f1f5f9',
		border: '#334155',
		accent: '#60a5fa',
		shadow: 'rgba(96, 165, 250, 0.2)',
		cursor: { primary: '#94a3b8', trail: 'rgba(148, 163, 184, 0.3)' },
		scrollButton: { bg: '#e2e8f0', text: '#0f172a', hover: '#cbd5e1' },
		dotIndicator: '#94a3b8',
		preview: 'linear-gradient(135deg, #1e293b 50%, #0f172a 50%)',
		semantic: {
			'--color-bg-primary': '#1e293b',
			'--color-bg-secondary': '#0f172a',
			'--color-text-primary': '#f1f5f9',
			'--color-text-secondary': '#94a3b8',
			'--color-border': '#334155',
			'--color-accent': '#60a5fa',
		}
	},
	retro: {
		bg: '#1a1a2e',
		bgSecondary: '#0d0d1a',
		text: '#f1f5f9',
		border: '#ff71ce',
		accent: '#00d4ff',
		shadow: 'rgba(255, 113, 206, 0.3)',
		cursor: { primary: '#ff71ce', trail: 'rgba(255, 113, 206, 0.4)' },
		scrollButton: { bg: '#ff71ce', text: '#000000', hover: '#ff99da' },
		dotIndicator: '#00d4ff',
		preview: 'linear-gradient(135deg, #00d4ff 50%, #ff71ce 50%)',
		semantic: {
			'--color-bg-primary': '#1a1a2e',
			'--color-bg-secondary': '#0d0d1a',
			'--color-text-primary': '#f1f5f9',
			'--color-text-secondary': '#cbd5e1',
			'--color-border': '#ff71ce',
			'--color-accent': '#00d4ff',
		}
	},
	matrix: {
		bg: '#000a00',
		bgSecondary: '#001a00',
		text: '#22c55e',
		border: '#166534',
		accent: '#00ff00',
		shadow: 'rgba(0, 255, 0, 0.3)',
		cursor: { primary: '#22c55e', trail: 'rgba(34, 197, 94, 0.4)' },
		scrollButton: { bg: '#22c55e', text: '#000000', hover: '#4ade80' },
		dotIndicator: '#22c55e',
		preview: 'linear-gradient(135deg, #22c55e 50%, #166534 50%)',
		semantic: {
			'--color-bg-primary': '#000a00',
			'--color-bg-secondary': '#001a00',
			'--color-text-primary': '#22c55e',
			'--color-text-secondary': '#86efac',
			'--color-border': '#166534',
			'--color-accent': '#00ff00',
		}
	},
	ocean: {
		bg: '#2e3440',
		bgSecondary: '#242933',
		text: '#88c0d0',
		border: '#5e81ac',
		accent: '#88c0d0',
		shadow: 'rgba(136, 192, 208, 0.25)',
		cursor: { primary: '#88c0d0', trail: 'rgba(136, 192, 208, 0.4)' },
		scrollButton: { bg: '#88c0d0', text: '#2e3440', hover: '#a3d4e0' },
		dotIndicator: '#88c0d0',
		preview: 'linear-gradient(135deg, #88c0d0 50%, #5e81ac 50%)',
		semantic: {
			'--color-bg-primary': '#2e3440',
			'--color-bg-secondary': '#242933',
			'--color-text-primary': '#88c0d0',
			'--color-text-secondary': '#81a1c1',
			'--color-border': '#5e81ac',
			'--color-accent': '#88c0d0',
		}
	},
	sunset: {
		bg: '#1c1309',
		bgSecondary: '#0e0904',
		text: '#fed7aa',
		border: '#f97316',
		accent: '#f97316',
		shadow: 'rgba(249, 115, 22, 0.25)',
		cursor: { primary: '#f97316', trail: 'rgba(249, 115, 22, 0.4)' },
		scrollButton: { bg: '#f97316', text: '#ffffff', hover: '#fb923c' },
		dotIndicator: '#fed7aa',
		preview: 'linear-gradient(135deg, #f97316 50%, #431407 50%)',
		semantic: {
			'--color-bg-primary': '#1c1309',
			'--color-bg-secondary': '#0e0904',
			'--color-text-primary': '#fed7aa',
			'--color-text-secondary': '#fdba74',
			'--color-border': '#f97316',
			'--color-accent': '#f97316',
		}
	},
	hotdog: {
		bg: '#008080',
		bgSecondary: '#006666',
		text: '#fff59d',
		border: '#ff0000',
		accent: '#ff0000',
		shadow: 'rgba(255, 0, 0, 0.3)',
		cursor: { primary: '#fff59d', trail: 'rgba(255, 245, 157, 0.4)' },
		scrollButton: { bg: '#ff0000', text: '#fff59d', hover: '#ff3333' },
		dotIndicator: '#fff59d',
		preview: 'linear-gradient(135deg, #008080 50%, #fff59d 50%)',
		semantic: {
			'--color-bg-primary': '#008080',
			'--color-bg-secondary': '#006666',
			'--color-text-primary': '#fff59d',
			'--color-text-secondary': '#ffffb3',
			'--color-border': '#ff0000',
			'--color-accent': '#ff0000',
		}
	},
	dracula: {
		bg: '#282a36',
		bgSecondary: '#1d1e26',
		text: '#f8f8f2',
		border: '#44475a',
		accent: '#bd93f9',
		shadow: 'rgba(189, 147, 249, 0.3)',
		cursor: { primary: '#bd93f9', trail: 'rgba(189, 147, 249, 0.4)' },
		scrollButton: { bg: '#bd93f9', text: '#000000', hover: '#d4b4ff' },
		dotIndicator: '#bd93f9',
		preview: 'linear-gradient(135deg, #bd93f9 50%, #282a36 50%)',
		semantic: {
			'--color-bg-primary': '#282a36',
			'--color-bg-secondary': '#1d1e26',
			'--color-text-primary': '#f8f8f2',
			'--color-text-secondary': '#bfc7d5',
			'--color-border': '#44475a',
			'--color-accent': '#bd93f9',
		}
	},
	cyberpunk: {
		bg: '#0d0221',
		bgSecondary: '#060115',
		text: '#00ffff',
		border: '#ff00ff',
		accent: '#ff00ff',
		shadow: 'rgba(255, 0, 255, 0.3)',
		cursor: { primary: '#ff00ff', trail: 'rgba(255, 0, 255, 0.4)' },
		scrollButton: { bg: '#ff00ff', text: '#ffffff', hover: '#ff66ff' },
		dotIndicator: '#00ffff',
		preview: 'linear-gradient(135deg, #ff00ff 50%, #00ffff 50%)',
		semantic: {
			'--color-bg-primary': '#0d0221',
			'--color-bg-secondary': '#060115',
			'--color-text-primary': '#00ffff',
			'--color-text-secondary': '#67ffff',
			'--color-border': '#ff00ff',
			'--color-accent': '#ff00ff',
		}
	},
	forest: {
		bg: '#1a2e1a',
		bgSecondary: '#0f1a0f',
		text: '#d1fae5',
		border: '#166534',
		accent: '#4ade80',
		shadow: 'rgba(74, 222, 128, 0.25)',
		cursor: { primary: '#4ade80', trail: 'rgba(74, 222, 128, 0.4)' },
		scrollButton: { bg: '#4ade80', text: '#000000', hover: '#6ee7a0' },
		dotIndicator: '#4ade80',
		preview: 'linear-gradient(135deg, #4ade80 50%, #1a2e1a 50%)',
		semantic: {
			'--color-bg-primary': '#1a2e1a',
			'--color-bg-secondary': '#0f1a0f',
			'--color-text-primary': '#d1fae5',
			'--color-text-secondary': '#a7f3d0',
			'--color-border': '#166534',
			'--color-accent': '#4ade80',
		}
	}
};

export const themeState = $state({
	theme: 'light' as ThemeStyle,
	effects: true,
	mounted: false
});

export function getThemeColors(theme: ThemeStyle): ThemeColors {
	return themes[theme];
}

export function getThemePreview(theme: ThemeStyle): string {
	return themes[theme].preview;
}

export function getCursorColors(theme: ThemeStyle): { primary: string; trail: string } {
	return themes[theme].cursor;
}

export function getScrollButtonColors(theme: ThemeStyle): { bg: string; text: string; hover: string } {
	return themes[theme].scrollButton;
}

export function getThemeAccentColors(theme: ThemeStyle): { bg: string; bgSecondary: string; text: string; border: string; accent: string; shadow: string } {
	const t = themes[theme];
	return { bg: t.bg, bgSecondary: t.bgSecondary, text: t.text, border: t.border, accent: t.accent, shadow: t.shadow };
}

export function getDotIndicatorColors(theme: ThemeStyle): string {
	return themes[theme].dotIndicator;
}

export interface ThemeTokens {
	colors: ThemeColors;
	preview: string;
	cursor: { primary: string; trail: string };
	scrollButton: { bg: string; text: string; hover: string };
	dotIndicator: string;
}

// Memoized theme tokens by theme
const themeTokenCache = new Map<string, ThemeTokens>();

export function getThemeTokens(theme: ThemeStyle): ThemeTokens {
	const cacheKey = theme;
	if (!themeTokenCache.has(cacheKey)) {
		const t = themes[theme];
		themeTokenCache.set(cacheKey, {
			colors: t,
			preview: t.preview,
			cursor: t.cursor,
			scrollButton: t.scrollButton,
			dotIndicator: t.dotIndicator
		});
	}
	return themeTokenCache.get(cacheKey)!;
}

export function clearThemeTokenCache() {
	themeTokenCache.clear();
}

export function initTheme() {
	if (typeof window === 'undefined') return;

	try {
		const savedTheme = localStorage.getItem('quickheadlines-theme') as ThemeStyle | null;
		if (savedTheme && themeStyles.some(t => t.id === savedTheme)) {
			themeState.theme = savedTheme;
		} else {
			themeState.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
		}
		applyTheme(themeState.theme);

		const savedEffects = localStorage.getItem('quickheadlines-effects');
		const savedCoolMode = localStorage.getItem('quickheadlines-coolmode');
		themeState.effects = savedEffects !== 'false' && savedCoolMode !== 'false';
	} catch {
		themeState.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
		applyTheme(themeState.theme);
	}

	themeState.mounted = true;
}

export function applyTheme(theme: ThemeStyle) {
	const isDarkMode = theme === 'dark';
	const isCustomTheme = customThemeIds.includes(theme as CustomThemeId);
	
	document.documentElement.setAttribute('data-theme', theme);
	document.documentElement.classList.toggle('dark', isDarkMode || isCustomTheme);
	
	applyCustomThemeColors(theme);
	
	if (isCustomTheme) {
		document.documentElement.classList.add('custom-theme');
	} else {
		document.documentElement.classList.remove('custom-theme');
	}
}

function applyCustomThemeColors(theme: ThemeStyle) {
	const t = themes[theme];
	document.documentElement.style.setProperty('--theme-bg', t.bg);
	document.documentElement.style.setProperty('--theme-text', t.text);
	document.documentElement.style.setProperty('--theme-border', t.border);
	document.documentElement.style.setProperty('--theme-accent', t.accent);
	document.documentElement.style.setProperty('--theme-shadow', t.shadow);
	
	if (t.semantic) {
		Object.entries(t.semantic).forEach(([key, value]) => {
			document.documentElement.style.setProperty(key, value);
		});
	}
}

export function setTheme(theme: ThemeStyle) {
	themeState.theme = theme;
	applyTheme(theme);
	clearThemeTokenCache(); // Clear cache when theme changes
	try {
		localStorage.setItem('quickheadlines-theme', theme);
	} catch {
		// localStorage not available (private browsing)
	}
}

export function toggleTheme() {
	const newTheme = themeState.theme === 'light' ? 'dark' : 'light';
	setTheme(newTheme);
}

export function toggleEffects() {
	themeState.effects = !themeState.effects;
	try {
		localStorage.setItem('quickheadlines-effects', String(themeState.effects));
	} catch {
		// localStorage not available
	}
}
