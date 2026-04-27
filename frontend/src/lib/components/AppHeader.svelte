<script lang="ts">
	import { themeState, toggleEffects, getThemeColors } from '$lib/stores/theme.svelte';
	import { readModeState, toggleReadMode } from '$lib/stores/readMode.svelte';
	import ThemePicker from './ThemePicker.svelte';
	import TabSelector from './TabSelector.svelte';
	import { goto } from '$app/navigation';
	import type { TabResponse } from '$lib/types';
	import { spacing } from '$lib/design/tokens';
	import { NavigationService } from '$lib/services/navigationService';
	interface Props {
		title: string;
		tabs?: TabResponse[];
		activeTab?: string;
		onTabChange?: (tab: string) => void;
		viewLink: { href: string; icon: 'clock' | 'rss' };
		searchExpanded: boolean;
		onSearchToggle: () => void;
		onLogoClick?: () => void;
		actions?: import('svelte').Snippet;
		children?: import('svelte').Snippet;
	}

	let { 
		title, 
		tabs = [], 
		activeTab = 'all', 
		onTabChange,
		viewLink, 
		searchExpanded, 
		onSearchToggle, 
		onLogoClick,
		actions,
		children
	}: Props = $props();
	
	let resolvedThemeColors = $derived(getThemeColors(themeState.theme));
	let headerElement: HTMLElement | undefined = $state();

	function handleViewSwitch() {
		const currentTab = NavigationService.getCurrentTab();
		const isOnTimeline = typeof window !== 'undefined' && window.location.pathname.startsWith('/timeline');
		
		if (isOnTimeline) {
			NavigationService.navigateToFeeds(currentTab);
		} else {
			NavigationService.navigateToTimeline(currentTab);
		}
	}

	function handleLogoClick(e: Event) {
		e.preventDefault();
		if (onLogoClick) {
			onLogoClick();
		} else {
			goto('/?tab=all');
		}
	}

	function handleTabChange(tab: string) {
		if (onTabChange) {
			onTabChange(tab);
		}
	}

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

<header bind:this={headerElement} class="fixed top-0 left-0 right-0 z-30 theme-bg-primary/95 backdrop-blur-xl border-b theme-border/80" data-name="app-header">
	<div class="mx-auto px-4 md:px-6" style="max-width: 1400px;">
		<div class="flex items-center justify-between h-14">
			<div class="flex items-center gap-3 sm:gap-4 min-w-0">
				<a 
					href="/" 
					onclick={handleLogoClick}
					class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0"
				>
					<img src="/logo.svg" alt="Logo" class="w-8 h-8" />
					<span class="text-lg font-semibold theme-text-primary hidden sm:block">{title}</span>
				</a>
				
				{#if tabs.length > 0}
					<div class="hidden md:block pl-2">
						<TabSelector 
							{tabs} 
							{activeTab} 
							onTabChange={handleTabChange}
							maxInline={5}
						/>
					</div>
				{/if}
			</div>
			
			<div class="flex items-center gap-1">
				{#if actions}
					{@render actions()}
				{/if}
				{#if children}
					{@render children()}
				{/if}
				
				<button
					onclick={onSearchToggle}
					class="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors focus-visible:ring-2 focus-visible:ring-[var(--theme-accent)] focus-visible:ring-offset-1"
					class:bg-slate-100={searchExpanded}
					class:dark:bg-slate-800={searchExpanded}
					aria-label="Search"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</button>
				
				<button
					onclick={toggleReadMode}
					class="p-2.5 rounded-lg transition-colors focus-visible:ring-2 focus-visible:ring-[var(--theme-accent)] focus-visible:ring-offset-1"
					class:bg-slate-100={readModeState.mode === 'read'}
					class:dark:bg-slate-800={readModeState.mode === 'read'}
					aria-label={readModeState.mode === 'link' ? 'Switch to read mode' : 'Switch to link mode'}
					title={readModeState.mode === 'link' ? 'Switch to read mode' : 'Switch to link mode'}
				>
					{#if readModeState.mode === 'link'}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
						</svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
						</svg>
					{/if}
				</button>
				
				<button 
					onclick={handleViewSwitch}
					class="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors focus-visible:ring-2 focus-visible:ring-[var(--theme-accent)] focus-visible:ring-offset-1"
					aria-label={viewLink.icon === 'clock' ? 'Timeline view' : 'Feed view'}
				>
					{#if viewLink.icon === 'clock'}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10" />
							<polyline points="12 6 12 12 16 14" />
						</svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path d="M4 11a9 9 0 0 1 9 9" />
							<path d="M4 4a16 16 0 0 1 16 16" />
							<circle cx="5" cy="19" r="1" fill="currentColor" />
						</svg>
					{/if}
				</button>
				
				<button
					onclick={toggleEffects}
					class="p-2.5 rounded-lg transition-all duration-200 focus-visible:ring-2 focus-visible:ring-[var(--theme-accent)] focus-visible:ring-offset-1"
					style="background-color: {themeState.effects ? resolvedThemeColors.bgSecondary : 'transparent'};"
					aria-label="Toggle effects"
				>
					<svg 
						class="w-5 h-5 transition-all duration-200"
						class:drop-shadow-lg={themeState.effects}
						style="color: {themeState.effects ? resolvedThemeColors.accent : 'var(--color-text-primary, var(--theme-text))'};"
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
	</div>
</header>