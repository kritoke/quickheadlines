<script lang="ts">
	import { themeState } from '$lib/stores/theme.svelte';
	import MobileTabSheet from './MobileTabSheet.svelte';
	import type { TabResponse } from '$lib/types';
	import { spacing } from '$lib/design/tokens';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		onTabChange: (tab: string) => void;
		maxInline?: number;
	}

	let { tabs, activeTab, onTabChange, maxInline = 5 }: Props = $props();

	let showMore = $state(false);
	let showMobileSheet = $state(false);
	let isMobile = $state(false);
	let tabListElement: HTMLElement | undefined = $state();

	const allTabs = $derived([{ name: 'all' }, ...tabs]);
	const visibleTabs = $derived(isMobile ? [] : allTabs.slice(0, maxInline + 1));
	const overflowTabs = $derived(isMobile ? allTabs : allTabs.slice(maxInline + 1));
	const hasOverflow = $derived(overflowTabs.length > 0);

	function selectTab(tab: string) {
		onTabChange(tab === 'all' ? 'all' : tab);
		showMore = false;
		showMobileSheet = false;
	}

	function toggleMore() {
		showMore = !showMore;
	}

	function toggleMobileSheet() {
		showMobileSheet = true;
	}

	function handleKeyDown(e: KeyboardEvent, index: number) {
		if (e.key === 'ArrowRight') {
			e.preventDefault();
			const nextIndex = (index + 1) % visibleTabs.length;
			const buttons = tabListElement?.querySelectorAll('[role="tab"]');
			(buttons?.[nextIndex] as HTMLElement)?.focus();
		} else if (e.key === 'ArrowLeft') {
			e.preventDefault();
			const prevIndex = (index - 1 + visibleTabs.length) % visibleTabs.length;
			const buttons = tabListElement?.querySelectorAll('[role="tab"]');
			(buttons?.[prevIndex] as HTMLElement)?.focus();
		}
	}

	$effect(() => {
		if (typeof window === 'undefined') return;
		
		const checkMobile = () => {
			isMobile = window.innerWidth < 768;
		};
		
		checkMobile();
		window.addEventListener('resize', checkMobile);
		
		return () => window.removeEventListener('resize', checkMobile);
	});
</script>

{#if isMobile}
<!-- Mobile: Dropdown button + Bottom sheet -->
<div class="relative z-50">
	<button
		onclick={(e) => { e.preventDefault(); console.log('Mobile tab button clicked'); showMobileSheet = true; }}
		type="button"
		class="w-full px-4 {spacing.default} flex items-center justify-between bg-slate-50 dark:bg-slate-800 border-t border-slate-200 dark:border-slate-700 cursor-pointer pointer-events-auto touch-manipulation"
	>
		<span class="text-sm text-slate-600 dark:text-slate-400">Viewing:</span>
		<span class="flex items-center gap-2 text-sm font-medium text-slate-900 dark:text-white">
			{activeTab === 'all' ? 'All' : activeTab}
			<svg class="w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
			</svg>
		</span>
	</button>
</div>

<MobileTabSheet
	tabs={allTabs}
	{activeTab}
	open={showMobileSheet}
	onClose={() => showMobileSheet = false}
	onTabChange={selectTab}
/>
{:else}
<!-- Desktop: Inline tabs + More dropdown -->
<div 
	bind:this={tabListElement}
	class="flex items-center gap-1" 
	role="tablist"
>
	{#each visibleTabs as tab, i (tab.name)}
		<button
			type="button"
			role="tab"
			aria-selected={activeTab === tab.name}
			onclick={() => selectTab(tab.name)}
			onkeydown={(e) => handleKeyDown(e, i)}
			class="relative px-3 {spacing.default} text-sm font-medium rounded-md transition-colors cursor-pointer
				{activeTab === tab.name 
					? 'text-slate-900 dark:text-white' 
					: 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300'}"
		>
			{tab.name === 'all' ? 'All' : tab.name}
			{#if activeTab === tab.name}
				<div 
					class="absolute bottom-0 left-3 right-3 h-0.5 bg-blue-500 rounded-full"
					style="view-transition-name: tab-indicator;"
				></div>
			{/if}
		</button>
	{/each}

	{#if hasOverflow}
		<div class="relative">
			<button
				role="tab"
				type="button"
				onclick={toggleMore}
				class="px-3 {spacing.default} text-sm font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 rounded-md flex items-center gap-1 cursor-pointer"
				aria-expanded={showMore}
			>
				More
				<svg 
					class="w-4 h-4 transition-transform {showMore ? 'rotate-180' : ''}" 
					fill="none" 
					viewBox="0 0 24 24" 
					stroke="currentColor"
				>
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
				</svg>
			</button>

			{#if showMore}
				<div 
					class="absolute top-full left-0 mt-1 theme-bg-primary rounded-lg shadow-lg theme-border {spacing.default} min-w-[120px] z-50"
					role="menu"
				>
					{#each overflowTabs as tab (tab.name)}
						<button
							type="button"
							role="menuitem"
							onclick={() => selectTab(tab.name)}
							class="w-full px-4 {spacing.default} text-sm text-left hover:opacity-80 cursor-pointer
								{activeTab === tab.name 
									? 'theme-accent theme-accent-bg/10' 
									: 'theme-text-primary'}"
						>
							{tab.name === 'all' ? 'All' : tab.name}
						</button>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>

<!-- Click outside to close dropdown -->
{#if showMore}
	<button
		class="fixed inset-0 z-40"
		onclick={() => showMore = false}
		aria-label="Close dropdown"
	></button>
{/if}
{/if}
