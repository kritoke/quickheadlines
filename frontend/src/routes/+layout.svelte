<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	
	let { children } = $props();
	
	let theme = $state<'light' | 'dark'>('light');
	
	onMount(() => {
		const saved = localStorage.getItem('quickheadlines-theme');
		if (saved) {
			theme = saved as 'light' | 'dark';
		} else {
			theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
		}
		document.documentElement.setAttribute('data-theme', theme);
		if (theme === 'dark') {
			document.documentElement.classList.add('dark');
		}
	});
	
	function toggleTheme() {
		theme = theme === 'light' ? 'dark' : 'light';
		document.documentElement.setAttribute('data-theme', theme);
		document.documentElement.classList.toggle('dark', theme === 'dark');
		localStorage.setItem('quickheadlines-theme', theme);
	}
	
	export function setTheme(newTheme: 'light' | 'dark') {
		theme = newTheme;
		document.documentElement.setAttribute('data-theme', theme);
		document.documentElement.classList.toggle('dark', theme === 'dark');
		localStorage.setItem('quickheadlines-theme', theme);
	}
</script>

<div id="app" class="min-h-screen bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100">
	{@render children()}
</div>
