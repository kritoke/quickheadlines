export type ThemeStyle = 'light' | 'dark' | 'retro80s' | 'matrix' | 'ocean' | 'sunset' | 'hotdog' | 'dracula' | 'nord' | 'cyberpunk' | 'forest' | 'coffee' | 'vaporwave';

export const themeStyles: { id: ThemeStyle; name: string; description: string }[] = [
	{ id: 'light', name: 'Light', description: 'Clean light theme' },
	{ id: 'dark', name: 'Dark', description: 'Easy on the eyes' },
	{ id: 'retro80s', name: 'Retro 80s', description: 'Neon and synthwave' },
	{ id: 'matrix', name: 'Matrix', description: 'Digital green rain' },
	{ id: 'ocean', name: 'Ocean', description: 'Deep blue waves' },
	{ id: 'sunset', name: 'Sunset', description: 'Warm amber tones' },
	{ id: 'hotdog', name: 'Hot Dog Stand', description: 'Windows 3.1 vibes' },
	{ id: 'dracula', name: 'Dracula', description: 'Popular purple dark' },
	{ id: 'nord', name: 'Nord', description: 'Arctic bluish-gray' },
	{ id: 'cyberpunk', name: 'Cyberpunk', description: 'Neon magenta cyan' },
	{ id: 'forest', name: 'Forest', description: 'Earthy greens' },
	{ id: 'coffee', name: 'Coffee', description: 'Warm browns' },
	{ id: 'vaporwave', name: 'Vaporwave', description: 'Aesthetic pink teal' }
];

export const themeState = $state({
	theme: 'light' as ThemeStyle,
	effects: false,
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

	const savedEffects = localStorage.getItem('quickheadlines-effects');
	const savedCoolMode = localStorage.getItem('quickheadlines-coolmode');
	themeState.effects = savedEffects === 'true' || savedCoolMode === 'true';

	themeState.mounted = true;
}

export function applyTheme(theme: ThemeStyle) {
	const isDarkMode = theme === 'dark';
	const isCustomTheme = ['retro80s', 'matrix', 'ocean', 'sunset', 'hotdog', 'dracula', 'nord', 'cyberpunk', 'forest', 'coffee', 'vaporwave'].includes(theme);
	
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
			retro80s: { bg: '#1a1a2e', text: '#f1f5f9', border: '#ff2e63', accent: '#00d4ff', shadow: 'rgba(255, 46, 99, 0.3)' },
			matrix: { bg: '#000a00', text: '#22c55e', border: '#166534', accent: '#00ff00', shadow: 'rgba(0, 255, 0, 0.3)' },
			ocean: { bg: '#0c1929', text: '#7dd3fc', border: '#06b6d4', accent: '#fb7185', shadow: 'rgba(6, 182, 212, 0.25)' },
			sunset: { bg: '#1c1309', text: '#fed7aa', border: '#f97316', accent: '#f97316', shadow: 'rgba(249, 115, 22, 0.25)' },
			hotdog: { bg: '#008080', text: '#fff59d', border: '#ff0000', accent: '#ff0000', shadow: 'rgba(255, 0, 0, 0.3)' },
			dracula: { bg: '#282a36', text: '#f8f8f2', border: '#44475a', accent: '#bd93f9', shadow: 'rgba(189, 147, 249, 0.3)' },
			nord: { bg: '#2e3440', text: '#d8dee9', border: '#3b4252', accent: '#88c0d0', shadow: 'rgba(136, 192, 208, 0.25)' },
			cyberpunk: { bg: '#0d0221', text: '#00ffff', border: '#ff00ff', accent: '#ff00ff', shadow: 'rgba(255, 0, 255, 0.3)' },
			forest: { bg: '#1a2e1a', text: '#d1fae5', border: '#166534', accent: '#4ade80', shadow: 'rgba(74, 222, 128, 0.25)' },
			coffee: { bg: '#2c1810', text: '#fef3c7', border: '#78350f', accent: '#d97706', shadow: 'rgba(217, 119, 6, 0.25)' },
			vaporwave: { bg: '#1a0a2e', text: '#b967ff', border: '#ff71ce', accent: '#ff71ce', shadow: 'rgba(255, 113, 206, 0.3)' }
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

export function toggleEffects() {
	themeState.effects = !themeState.effects;
	localStorage.setItem('quickheadlines-effects', String(themeState.effects));
}

	export function getCursorColors(theme: ThemeStyle): { primary: string; trail: string } {
		const colors: Record<ThemeStyle, { primary: string; trail: string }> = {
			light: { primary: '#64748b', trail: 'rgba(100, 116, 139, 0.3)' },
			dark: { primary: '#94a3b8', trail: 'rgba(148, 163, 184, 0.3)' },
			retro80s: { primary: '#00d4ff', trail: 'rgba(0, 212, 255, 0.4)' },
			matrix: { primary: '#22c55e', trail: 'rgba(34, 197, 94, 0.4)' },
			ocean: { primary: '#fb7185', trail: 'rgba(251, 113, 133, 0.4)' },
			sunset: { primary: '#f97316', trail: 'rgba(249, 115, 22, 0.4)' },
			hotdog: { primary: '#fff59d', trail: 'rgba(255, 245, 157, 0.4)' },
			dracula: { primary: '#bd93f9', trail: 'rgba(189, 147, 249, 0.4)' },
			nord: { primary: '#88c0d0', trail: 'rgba(136, 192, 208, 0.4)' },
			cyberpunk: { primary: '#ff00ff', trail: 'rgba(255, 0, 255, 0.4)' },
			forest: { primary: '#4ade80', trail: 'rgba(74, 222, 128, 0.4)' },
			coffee: { primary: '#d97706', trail: 'rgba(217, 119, 6, 0.4)' },
			vaporwave: { primary: '#ff71ce', trail: 'rgba(255, 113, 206, 0.4)' }
		};
		return colors[theme];
	}

	export function getScrollButtonColors(theme: ThemeStyle): { bg: string; text: string; hover: string } {
		const colors: Record<ThemeStyle, { bg: string; text: string; hover: string }> = {
			light: { bg: '#334155', text: '#ffffff', hover: '#475569' },
			dark: { bg: '#e2e8f0', text: '#0f172a', hover: '#cbd5e1' },
			retro80s: { bg: '#00d4ff', text: '#000000', hover: '#33ddff' },
			matrix: { bg: '#22c55e', text: '#000000', hover: '#4ade80' },
			ocean: { bg: '#fb7185', text: '#ffffff', hover: '#fda4af' },
			sunset: { bg: '#f97316', text: '#ffffff', hover: '#fb923c' },
			hotdog: { bg: '#ff0000', text: '#fff59d', hover: '#ff3333' },
			dracula: { bg: '#bd93f9', text: '#000000', hover: '#d4b4ff' },
			nord: { bg: '#88c0d0', text: '#000000', hover: '#a3d4e0' },
			cyberpunk: { bg: '#ff00ff', text: '#ffffff', hover: '#ff66ff' },
			forest: { bg: '#4ade80', text: '#000000', hover: '#6ee7a0' },
			coffee: { bg: '#d97706', text: '#ffffff', hover: '#f59e0b' },
			vaporwave: { bg: '#ff71ce', text: '#000000', hover: '#ff99da' }
		};
		return colors[theme];
	}

	export function getThemeAccentColors(theme: ThemeStyle): { bg: string; bgSecondary: string; text: string; border: string; accent: string; shadow: string } {
		const colors: Record<ThemeStyle, { bg: string; bgSecondary: string; text: string; border: string; accent: string; shadow: string }> = {
			light: { bg: '#ffffff', bgSecondary: '#f1f5f9', text: '#0f172a', border: '#e2e8f0', accent: '#3b82f6', shadow: 'rgba(59, 130, 246, 0.15)' },
			dark: { bg: '#1e293b', bgSecondary: '#0f172a', text: '#f1f5f9', border: '#334155', accent: '#60a5fa', shadow: 'rgba(96, 165, 250, 0.2)' },
			retro80s: { bg: '#1a1a2e', bgSecondary: '#0d0d1a', text: '#f1f5f9', border: '#ff2e63', accent: '#00d4ff', shadow: 'rgba(255, 46, 99, 0.3)' },
			matrix: { bg: '#000a00', bgSecondary: '#001a00', text: '#22c55e', border: '#166534', accent: '#00ff00', shadow: 'rgba(0, 255, 0, 0.3)' },
			ocean: { bg: '#0c1929', bgSecondary: '#061018', text: '#7dd3fc', border: '#06b6d4', accent: '#fb7185', shadow: 'rgba(6, 182, 212, 0.25)' },
			sunset: { bg: '#1c1309', bgSecondary: '#0e0904', text: '#fed7aa', border: '#f97316', accent: '#f97316', shadow: 'rgba(249, 115, 22, 0.25)' },
			hotdog: { bg: '#008080', bgSecondary: '#006666', text: '#fff59d', border: '#ff0000', accent: '#ff0000', shadow: 'rgba(255, 0, 0, 0.3)' },
			dracula: { bg: '#282a36', bgSecondary: '#1d1e26', text: '#f8f8f2', border: '#44475a', accent: '#bd93f9', shadow: 'rgba(189, 147, 249, 0.3)' },
			nord: { bg: '#2e3440', bgSecondary: '#242933', text: '#d8dee9', border: '#3b4252', accent: '#88c0d0', shadow: 'rgba(136, 192, 208, 0.25)' },
			cyberpunk: { bg: '#0d0221', bgSecondary: '#060115', text: '#00ffff', border: '#ff00ff', accent: '#ff00ff', shadow: 'rgba(255, 0, 255, 0.3)' },
			forest: { bg: '#1a2e1a', bgSecondary: '#0f1a0f', text: '#d1fae5', border: '#166534', accent: '#4ade80', shadow: 'rgba(74, 222, 128, 0.25)' },
			coffee: { bg: '#2c1810', bgSecondary: '#1a0d09', text: '#fef3c7', border: '#78350f', accent: '#d97706', shadow: 'rgba(217, 119, 6, 0.25)' },
			vaporwave: { bg: '#1a0a2e', bgSecondary: '#0f0520', text: '#b967ff', border: '#ff71ce', accent: '#ff71ce', shadow: 'rgba(255, 113, 206, 0.3)' }
		};
		return colors[theme];
	}
