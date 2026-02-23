export type ThemeStyle = 'light' | 'dark' | 'retro80s' | 'matrix' | 'ocean' | 'sunset';

export const themeStyles: { id: ThemeStyle; name: string; description: string }[] = [
	{ id: 'light', name: 'Light', description: 'Clean light theme' },
	{ id: 'dark', name: 'Dark', description: 'Easy on the eyes' },
	{ id: 'retro80s', name: 'Retro 80s', description: 'Neon and synthwave' },
	{ id: 'matrix', name: 'Matrix', description: 'Digital green rain' },
	{ id: 'ocean', name: 'Ocean', description: 'Deep blue waves' },
	{ id: 'sunset', name: 'Sunset', description: 'Warm amber tones' }
];

export const themeState = $state({
	theme: 'light' as ThemeStyle,
	coolMode: false,
	mounted: false
});

export function initTheme() {
	if (typeof window === 'undefined') return;

	const savedTheme = localStorage.getItem('quickheadlines-theme') as ThemeStyle | null;
	if (savedTheme && themeStyles.some(t => t.id === savedTheme)) {
		themeState.theme = savedTheme;
	} else {
		themeState.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
	}
	applyTheme(themeState.theme);

	const savedCoolMode = localStorage.getItem('quickheadlines-coolmode');
	themeState.coolMode = savedCoolMode === 'true';

	themeState.mounted = true;
}

export function applyTheme(theme: ThemeStyle) {
	const isDarkMode = theme === 'dark';
	const isCustomTheme = ['retro80s', 'matrix', 'ocean', 'sunset'].includes(theme);
	
	document.documentElement.setAttribute('data-theme', theme);
	document.documentElement.classList.toggle('dark', isDarkMode || isCustomTheme);
	
	if (isCustomTheme) {
		document.documentElement.classList.add('custom-theme');
		applyCustomThemeColors(theme);
	} else {
		document.documentElement.classList.remove('custom-theme');
	}
}

function applyCustomThemeColors(theme: ThemeStyle) {
	const colors: Record<ThemeStyle, { bg: string; text: string; border: string; accent: string; shadow: string }> = {
		light: { bg: '#ffffff', text: '#0f172a', border: '#e2e8f0', accent: '#3b82f6', shadow: 'rgba(59, 130, 246, 0.15)' },
		dark: { bg: '#1e293b', text: '#f1f5f9', border: '#334155', accent: '#60a5fa', shadow: 'rgba(96, 165, 250, 0.2)' },
		retro80s: { bg: '#1a1a2e', text: '#e94560', border: '#16213e', accent: '#ff2e63', shadow: 'rgba(255, 46, 99, 0.3)' },
		matrix: { bg: '#000000', text: '#00ff00', border: '#003b00', accent: '#00ff00', shadow: 'rgba(0, 255, 0, 0.3)' },
		ocean: { bg: '#0c1929', text: '#7dd3fc', border: '#164e63', accent: '#06b6d4', shadow: 'rgba(6, 182, 212, 0.25)' },
		sunset: { bg: '#1c1309', text: '#fed7aa', border: '#7c2d12', accent: '#f97316', shadow: 'rgba(249, 115, 22, 0.25)' }
	};
	
	const c = colors[theme];
	document.documentElement.style.setProperty('--theme-bg', c.bg);
	document.documentElement.style.setProperty('--theme-text', c.text);
	document.documentElement.style.setProperty('--theme-border', c.border);
	document.documentElement.style.setProperty('--theme-accent', c.accent);
	document.documentElement.style.setProperty('--theme-shadow', c.shadow);
}

export function setTheme(theme: ThemeStyle) {
	themeState.theme = theme;
	applyTheme(theme);
	localStorage.setItem('quickheadlines-theme', theme);
}

export function toggleTheme() {
	const newTheme = themeState.theme === 'light' ? 'dark' : 'light';
	setTheme(newTheme);
}

export function toggleCoolMode() {
	themeState.coolMode = !themeState.coolMode;
	localStorage.setItem('quickheadlines-coolmode', String(themeState.coolMode));
}

export function getCursorColors(theme: ThemeStyle): { primary: string; trail: string } {
	const colors: Record<ThemeStyle, { primary: string; trail: string }> = {
		light: { primary: '#64748b', trail: 'rgba(100, 116, 139, 0.3)' },
		dark: { primary: '#94a3b8', trail: 'rgba(148, 163, 184, 0.3)' },
		retro80s: { primary: '#ff2e63', trail: 'rgba(255, 46, 99, 0.4)' },
		matrix: { primary: '#00ff00', trail: 'rgba(0, 255, 0, 0.4)' },
		ocean: { primary: '#06b6d4', trail: 'rgba(6, 182, 212, 0.4)' },
		sunset: { primary: '#f97316', trail: 'rgba(249, 115, 22, 0.4)' }
	};
	return colors[theme];
}

export function getScrollButtonColors(theme: ThemeStyle): { bg: string; text: string; hover: string } {
	const colors: Record<ThemeStyle, { bg: string; text: string; hover: string }> = {
		light: { bg: '#334155', text: '#ffffff', hover: '#475569' },
		dark: { bg: '#e2e8f0', text: '#0f172a', hover: '#cbd5e1' },
		retro80s: { bg: '#ff2e63', text: '#ffffff', hover: '#ff5a7d' },
		matrix: { bg: '#00ff00', text: '#000000', hover: '#33ff33' },
		ocean: { bg: '#06b6d4', text: '#000000', hover: '#22d3ee' },
		sunset: { bg: '#f97316', text: '#ffffff', hover: '#fb923c' }
	};
	return colors[theme];
}

export function getThemeAccentColors(theme: ThemeStyle): { bg: string; text: string; border: string; accent: string; shadow: string } {
	const colors: Record<ThemeStyle, { bg: string; text: string; border: string; accent: string; shadow: string }> = {
		light: { bg: '#ffffff', text: '#0f172a', border: '#e2e8f0', accent: '#3b82f6', shadow: 'rgba(59, 130, 246, 0.15)' },
		dark: { bg: '#1e293b', text: '#f1f5f9', border: '#334155', accent: '#60a5fa', shadow: 'rgba(96, 165, 250, 0.2)' },
		retro80s: { bg: '#1a1a2e', text: '#e94560', border: '#16213e', accent: '#ff2e63', shadow: 'rgba(255, 46, 99, 0.3)' },
		matrix: { bg: '#000000', text: '#00ff00', border: '#003b00', accent: '#00ff00', shadow: 'rgba(0, 255, 0, 0.3)' },
		ocean: { bg: '#0c1929', text: '#7dd3fc', border: '#164e63', accent: '#06b6d4', shadow: 'rgba(6, 182, 212, 0.25)' },
		sunset: { bg: '#1c1309', text: '#fed7aa', border: '#7c2d12', accent: '#f97316', shadow: 'rgba(249, 115, 22, 0.25)' }
	};
	return colors[theme];
}
