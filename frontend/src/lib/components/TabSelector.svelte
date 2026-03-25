<script lang="ts">
	import { themeState } from '$lib/stores/theme.svelte';
	import MobileTabSheet from './MobileTabSheet.svelte';
	import type { TabResponse } from '$lib/types';
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
	<div class="fixed bottom-0 left-0 right-0 z-50">
		<button
			onclick={(e) => { e.preventDefault(); showMobileSheet = true; }}
			type="button"
			class="w-full h-16 px-4 flex items-center justify-between theme-bg-primary/90 backdrop-blur-xl border-t theme-border shadow-[0_-4px_20px_rgba(0,0,0,0.1)] dark:shadow-[0_-4px_20px_rgba(0,0,0,0.3)] cursor-pointer"
		>
			<span class="text-sm theme-text-secondary">Viewing:</span>
			<span class="flex items-center gap-2 text-sm font-semibold theme-text-primary">
				{activeTab === 'all' ? 'All' : activeTab}
				<svg class="w-4 h-4 theme-text-secondary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
				class="relative px-4 py-2 text-sm font-medium rounded-lg transition-all duration-200 cursor-pointer
					{activeTab === tab.name 
						? 'theme-text-primary theme-bg-secondary' 
						: 'theme-text-secondary hover:theme-text-primary hover:theme-bg-secondary/50'}"
			>
				{tab.name === 'all' ? 'All' : tab.name}
			</button>
		{/each}

		{#if hasOverflow}
			<div class="relative">
				<button
					role="tab"
					type="button"
					onclick={toggleMore}
					class="px-4 py-2 text-sm font-medium theme-text-secondary hover:theme-text-primary rounded-lg flex items-center gap-1 cursor-pointer hover:theme-bg-secondary/50 transition-colors"
					aria-expanded={showMore}
				>
					More
					<svg 
						class="w-4 h-4 transition-transform duration-200 {showMore ? 'rotate-180' : ''}" 
						fill="none" 
						viewBox="0 0 24 24" 
						stroke="currentColor"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>

				{#if showMore}
					<div 
						class="absolute top-full left-0 mt-2 theme-bg-primary rounded-xl shadow-lg theme-border border py-1 min-w-[140px] z-50"
						role="menu"
					>
						{#each overflowTabs as tab (tab.name)}
							<button
								type="button"
								role="menuitem"
								onclick={() => selectTab(tab.name)}
								class="w-full px-4 py-2.5 text-sm text-left hover:theme-bg-secondary cursor-pointer transition-colors
									{activeTab === tab.name 
										? 'theme-text-primary font-medium' 
										: 'theme-text-secondary'}"
							>
								{tab.name === 'all' ? 'All' : tab.name}
							</button>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	{#if showMore}
		<button
			class="fixed inset-0 z-40"
			onclick={() => showMore = false}
			aria-label="Close dropdown"
		></button>
	{/if}
{/if}