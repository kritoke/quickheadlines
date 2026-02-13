<script lang="ts">
	import { getTheme, toggleTheme } from '$lib/stores/theme.svelte';
</script>

<header class="sticky top-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20">
	<div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
		<div class="flex items-center gap-3">
			<a href="/" class="flex items-center gap-3 hover:opacity-80 transition-opacity">
				<img src="/logo.svg" alt="Logo" class="w-8 h-8" />
				<h1 class="text-xl font-bold text-slate-900 dark:text-white">
					QuickHeadlines
				</h1>
			</a>
		</div>
		<div class="flex items-center gap-4">
			<slot name="left" />
			<a href="/timeline" class="text-sm text-blue-600 dark:text-blue-400 hover:underline">
				Timeline
			</a>
			<button
				onclick={toggleTheme}
				class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
				aria-label="Toggle theme"
			>
				{#if getTheme() === 'dark'}
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-yellow-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
					</svg>
				{:else}
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-600 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
					</svg>
				{/if}
			</button>
		</div>
	</div>
</header>
