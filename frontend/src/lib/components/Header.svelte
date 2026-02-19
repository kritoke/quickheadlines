<script lang="ts">
	import { themeState, toggleCoolMode } from '$lib/stores/theme.svelte';
	import AnimatedThemeToggler from './AnimatedThemeToggler.svelte';
</script>

<header class="sticky top-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-20">
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
				aria-label="Toggle cool mode"
				title="Toggle particle effects"
			>
				<svg 
					class="w-5 h-5"
					class:text-pink-500={themeState.coolMode}
					class:text-slate-400={!themeState.coolMode}
					class:dark:text-slate-500={!themeState.coolMode}
					viewBox="0 0 24 24" 
					fill="currentColor"
				>
					<circle cx="5" cy="5" r="2.5" />
					<circle cx="12" cy="8" r="2" />
					<circle cx="19" cy="5" r="2.5" />
					<circle cx="7" cy="12" r="1.5" />
					<circle cx="17" cy="12" r="1.5" />
					<circle cx="5" cy="19" r="2.5" />
					<circle cx="12" cy="16" r="2" />
					<circle cx="19" cy="19" r="2.5" />
				</svg>
			</button>
			<AnimatedThemeToggler />
		</div>
	</div>
</header>
