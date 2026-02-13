let theme = $state<'light' | 'dark'>('light');
let mounted = $state(false);

export function initTheme() {
	if (typeof window === 'undefined') return;
	
	const saved = localStorage.getItem('quickheadlines-theme');
	if (saved) {
		theme = saved as 'light' | 'dark';
	} else {
		theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
	}
	document.documentElement.classList.toggle('dark', theme === 'dark');
	mounted = true;
}

export function toggleTheme() {
	theme = theme === 'light' ? 'dark' : 'light';
	document.documentElement.classList.toggle('dark', theme === 'dark');
	localStorage.setItem('quickheadlines-theme', theme);
}

export function getTheme() {
	return theme;
}

export function isMounted() {
	return mounted;
}
