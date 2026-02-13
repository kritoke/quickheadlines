export const themeState = $state({
	theme: 'light' as 'light' | 'dark',
	mounted: false
});

export function initTheme() {
	if (typeof window === 'undefined') return;
	
	const saved = localStorage.getItem('quickheadlines-theme');
	if (saved) {
		themeState.theme = saved as 'light' | 'dark';
	} else {
		themeState.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
	}
	document.documentElement.classList.toggle('dark', themeState.theme === 'dark');
	themeState.mounted = true;
	console.log('[ThemeStore] Initialized, theme:', themeState.theme, 'mounted:', themeState.mounted);
}

export function toggleTheme() {
	themeState.theme = themeState.theme === 'light' ? 'dark' : 'light';
	document.documentElement.classList.toggle('dark', themeState.theme === 'dark');
	localStorage.setItem('quickheadlines-theme', themeState.theme);
	console.log('[ThemeStore] Toggled to:', themeState.theme);
}
