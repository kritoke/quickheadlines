export const themeState = $state({
	theme: 'light' as 'light' | 'dark',
	coolMode: false,
	mounted: false
});

export function initTheme() {
	if (typeof window === 'undefined') return;

	const savedTheme = localStorage.getItem('quickheadlines-theme');
	if (savedTheme) {
		themeState.theme = savedTheme as 'light' | 'dark';
	} else {
		themeState.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
	}
	document.documentElement.classList.toggle('dark', themeState.theme === 'dark');

	const savedCoolMode = localStorage.getItem('quickheadlines-coolmode');
	themeState.coolMode = savedCoolMode === 'true';

	themeState.mounted = true;
}

export function toggleTheme() {
	themeState.theme = themeState.theme === 'light' ? 'dark' : 'light';
	document.documentElement.classList.toggle('dark', themeState.theme === 'dark');
	localStorage.setItem('quickheadlines-theme', themeState.theme);
}

export function toggleCoolMode() {
	themeState.coolMode = !themeState.coolMode;
	localStorage.setItem('quickheadlines-coolmode', String(themeState.coolMode));
}
