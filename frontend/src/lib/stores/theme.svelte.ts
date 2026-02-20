export const themeState = $state({
	theme: 'light' as 'light' | 'dark',
	cursorTrail: false,
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

	const savedCursorTrail = localStorage.getItem('quickheadlines-cursortrail');
	themeState.cursorTrail = savedCursorTrail === 'true';

	themeState.mounted = true;
}

export function toggleTheme() {
	themeState.theme = themeState.theme === 'light' ? 'dark' : 'light';
	document.documentElement.classList.toggle('dark', themeState.theme === 'dark');
	localStorage.setItem('quickheadlines-theme', themeState.theme);
}

export function toggleCursorTrail() {
	themeState.cursorTrail = !themeState.cursorTrail;
	localStorage.setItem('quickheadlines-cursortrail', String(themeState.cursorTrail));
}
