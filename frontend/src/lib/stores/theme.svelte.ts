class ThemeStore {
	theme = $state<'light' | 'dark'>('light');
	mounted = $state(false);

	init() {
		if (typeof window === 'undefined') return;
		
		const saved = localStorage.getItem('quickheadlines-theme');
		if (saved) {
			this.theme = saved as 'light' | 'dark';
		} else {
			this.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
		}
		document.documentElement.classList.toggle('dark', this.theme === 'dark');
		this.mounted = true;
	}

	toggle() {
		this.theme = this.theme === 'light' ? 'dark' : 'light';
		document.documentElement.classList.toggle('dark', this.theme === 'dark');
		localStorage.setItem('quickheadlines-theme', this.theme);
	}

	get isDark() {
		return this.theme === 'dark';
	}

	get isMounted() {
		return this.mounted;
	}
}

export const themeStore = new ThemeStore();
