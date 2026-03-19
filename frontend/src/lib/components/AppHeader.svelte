<script lang="ts">
	import { themeState, toggleEffects, getThemeColors } from '$lib/stores/theme.svelte';
	import ThemePicker from './ThemePicker.svelte';
	import TabSelector from './TabSelector.svelte';
	import { goto } from '$app/navigation';
	import type { TabResponse } from '$lib/types';
	import { spacing } from '$lib/design/tokens';

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

	function handleViewSwitch(e: Event) {
		e.preventDefault();
		goto(viewLink.href);
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

<header bind:this={headerElement} class="fixed top-0 left-0 right-0 theme-bg-primary/95 backdrop-blur shadow-sm z-30" data-name="app-header">
	<div class="mx-auto px-4 md:px-8" style="max-width: 1400px;">
		<div class="flex items-center justify-between h-14">
			<!-- Logo + Tabs -->
			<div class="flex items-center gap-2 sm:gap-4 min-w-0">
				<button onclick={handleLogoClick} class="flex items-center gap-2 hover:opacity-80 transition-opacity shrink-0">
					<img src="/logo.svg" alt="Logo" class="w-7 h-7 sm:w-8 sm:h-8" />
					<span class="text-lg sm:text-xl font-bold theme-text-primary hidden sm:block">{title}</span>
				</button>
				
				{#if tabs.length > 0}
					<div class="hidden md:block">
						<TabSelector 
							{tabs} 
							{activeTab} 
							onTabChange={handleTabChange}
							maxInline={5}
						/>
					</div>
				{/if}
			</div>
			
			<!-- Actions -->
			<div class="flex items-center gap-1 sm:gap-2">
				{#if actions}
					{@render actions()}
				{/if}
				{#if children}
					{@render children()}
				{/if}
				<button
					onclick={onSearchToggle}
					class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					class:bg-slate-100={searchExpanded}
					class:dark:bg-slate-800={searchExpanded}
					aria-label="Search"
					title="Search"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</button>
				<!-- Global Timeline button -->
				<button 
					onclick={() => goto('/timeline')}
					class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Global Timeline"
					title="Global Timeline"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-500 dark:text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10" />
						<path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
					</svg>
				</button>
				<button 
					onclick={handleViewSwitch}
					class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label={viewLink.icon === 'clock' ? 'Tab Timeline view' : 'Feed view'}
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
				</button>
				<button
					onclick={toggleEffects}
					class="p-2 rounded-lg transition-colors"
					style="background-color: {themeState.effects ? resolvedThemeColors.bgSecondary : 'transparent'}; opacity: {themeState.effects ? 1 : 0.7};"
					aria-label="Toggle effects"
					title="Effects"
				>
					<svg 
						class="w-5 h-5 transition-all duration-200"
						class:drop-shadow-lg={themeState.effects}
						style="color: {themeState.effects ? resolvedThemeColors.accent : '#94a3b8'};"
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
