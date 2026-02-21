<script lang="ts">
	import { themeState, toggleCoolMode } from '$lib/stores/theme.svelte';
	import AnimatedThemeToggler from './AnimatedThemeToggler.svelte';
</script>

<header class="sticky top-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20" data-name="main-header">
	<div class="max-w-7xl mx-auto px-2 sm:px-4 py-2 sm:py-3 flex items-center justify-between">
		<div class="flex items-center gap-2 sm:gap-3">
			<a href="/" class="flex items-center gap-2 sm:gap-3 hover:opacity-80 transition-opacity">
				<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
				<h1 class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white hidden sm:block">
					QuickHeadlines
				</h1>
			</a>
		</div>
		<div class="flex items-center gap-1 sm:gap-2">
			<slot name="left" />
			<a href="/timeline" class="text-xs sm:text-sm text-blue-600 dark:text-blue-400 hover:underline sm:mr-2">
				Timeline
			</a>
			<button
				onclick={toggleCoolMode}
				class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
				aria-label="Toggle cursor trail"
				title="Cursor trail"
			>
				<svg 
					class="w-5 h-5 transition-colors duration-200"
					style={themeState.coolMode ? 'color: #6b8e5f;' : 'color: #94a3b8;'}
					viewBox="0 0 24 24" 
					fill="currentColor"
				>
					<path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z" />
					<path d="M13 13l6 6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" />
				</svg>
			</button>
			<AnimatedThemeToggler />
		</div>
	</div>
</header>
