// Theme store - must export as const object (not reassigned) for cross-module reactivity
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
}

export function toggleTheme() {
	themeState.theme = themeState.theme === 'light' ? 'dark' : 'light';
	document.documentElement.classList.toggle('dark', themeState.theme === 'dark');
	localStorage.setItem('quickheadlines-theme', themeState.theme);
}
