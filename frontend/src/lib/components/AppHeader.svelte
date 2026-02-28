<script lang="ts">
	import { themeState, toggleCoolMode, toggleCursorTrail, getThemeAccentColors } from '$lib/stores/theme.svelte';
	import ThemePicker from './ThemePicker.svelte';
	import type { Snippet } from 'svelte';

	interface Props {
		title: string;
		viewLink: { href: string; icon: 'clock' | 'rss' };
		searchExpanded: boolean;
		onSearchToggle: () => void;
		metadata?: Snippet;
		tabContent?: Snippet;
	}

	let { title, viewLink, searchExpanded, onSearchToggle, metadata, tabContent }: Props = $props();
	let themeColors = $derived(getThemeAccentColors(themeState.theme));
	let headerElement: HTMLElement | undefined = $state();

	$effect(() => {
		if (typeof window === 'undefined' || !headerElement) return;
		
		const observer = new ResizeObserver((entries) => {
			const height = entries[0].contentRect.height;
			document.documentElement.style.setProperty('--header-height', `${height}px`);
		});
		
		observer.observe(headerElement);
		
		return () => observer.disconnect();
	});
</script>

<header bind:this={headerElement} class="fixed top-0 left-0 right-0 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-700 z-30" data-name="app-header">
	<div class="mx-auto px-4 md:px-8 xl:px-12" style="max-width: 1800px;">
		<div class="flex items-center justify-between py-2">
			<div class="flex items-center gap-2 sm:gap-3 min-w-0">
				<a href={viewLink.icon === 'clock' ? '/?tab=all' : '/'} class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0">
					<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
					<span class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">{title}</span>
				</a>
				{#if metadata}
					{@render metadata()}
				{/if}
			</div>
			<div class="flex items-center gap-1 sm:gap-2">
				<button
					onclick={onSearchToggle}
					class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					class:bg-slate-100={searchExpanded}
					class:dark:bg-slate-800={searchExpanded}
					aria-label="Search"
					title="Search"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</button>
				<a 
					href={viewLink.href} 
					class="p-1.5 sm:p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label={viewLink.icon === 'clock' ? 'Timeline view' : 'Feed view'}
					title={viewLink.icon === 'clock' ? 'Timeline' : 'Feeds'}
				>
					{#if viewLink.icon === 'clock'}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10" />
							<polyline points="12 6 12 12 16 14" />
						</svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path d="M4 11a9 9 0 0 1 9 9" />
							<path d="M4 4a16 16 0 0 1 16 16" />
							<circle cx="5" cy="19" r="1" fill="currentColor" />
						</svg>
					{/if}
				</a>
				<button
					onclick={toggleCursorTrail}
					class="p-1.5 sm:p-2 rounded-lg transition-colors"
					style="background-color: {themeState.cursorTrail ? themeColors.bgSecondary : 'transparent'}; opacity: {themeState.cursorTrail ? 1 : 0.7};"
					aria-label="Toggle cursor trail"
					title="Cursor trail"
				>
					<svg 
						class="w-5 h-5 transition-all duration-200"
						class:drop-shadow-lg={themeState.cursorTrail}
						style="color: {themeState.cursorTrail ? themeColors.accent : '#94a3b8'};"
						viewBox="0 0 24 24" 
						fill="currentColor"
					>
						<path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z" />
						<path d="M13 13l6 6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" />
					</svg>
				</button>
				<ThemePicker />
			</div>
		</div>
		{#if tabContent}
			<div class="hidden md:block pb-2">
				{@render tabContent()}
			</div>
			<div class="md:hidden -mx-2 px-2">
				{@render tabContent()}
			</div>
		{/if}
	</div>
</header>
