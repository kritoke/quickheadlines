<script lang="ts">
	import { breakpointState } from '$lib/utils/breakpoint.svelte';
	import { Tabs } from '@skeletonlabs/skeleton-svelte';
	import MobileTabSheet from './MobileTabSheet.svelte';
	import type { TabResponse } from '$lib/types';
	import { cn } from '$lib/utils';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		onTabChange: (tab: string) => void;
		maxInline?: number;
	}

	let { tabs, activeTab, onTabChange, maxInline = 5 }: Props = $props();

	let showMore = $state(false);
	let showMobileSheet = $state(false);
	let isMobile = $derived(breakpointState.isMobile);

	const allTabs = $derived([{ name: 'all' }, ...tabs]);
	const visibleTabs = $derived(isMobile ? [] : allTabs.slice(0, maxInline + 1));
	const overflowTabs = $derived(isMobile ? allTabs : allTabs.slice(maxInline + 1));
	const hasOverflow = $derived(overflowTabs.length > 0);

	function selectTab(tab: string) {
		onTabChange(tab);
		showMore = false;
		showMobileSheet = false;
	}

	function toggleMore() {
		showMore = !showMore;
	}
</script>

{#if isMobile}
	<div class="fixed bottom-0 left-0 right-0 z-50">
		<button
			onclick={(e) => { e.preventDefault(); showMobileSheet = true; }}
			type="button"
			class="w-full h-16 px-4 flex items-center justify-between bg-surface-50/90 dark:bg-surface-950/90 backdrop-blur-xl border-t border-surface-200 dark:border-surface-700 shadow-[0_-4px_20px_rgba(0,0,0,0.1)] dark:shadow-[0_-4px_20px_rgba(0,0,0,0.3)] cursor-pointer"
		>
			<span class="text-sm text-surface-700 dark:text-surface-300">Viewing:</span>
			<span class="flex items-center gap-2 text-sm font-semibold text-surface-950 dark:text-surface-50">
				{activeTab === 'all' ? 'All' : activeTab}
				<svg class="w-4 h-4 text-surface-700 dark:text-surface-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
	<Tabs value={activeTab} onValueChange={(details) => selectTab(details.value)}>
		<Tabs.List class="flex items-center gap-1 border-b-0! mb-0! pb-0!">
			{#each visibleTabs as tab (tab.name)}
				<Tabs.Trigger
					value={tab.name}
					class={cn(
						'relative px-4 py-2 text-sm font-medium rounded-lg transition-all duration-200 cursor-pointer',
						activeTab === tab.name
							? 'text-white bg-[var(--color-primary-500,#334155)]'
							: 'text-surface-700 dark:text-surface-300 hover:bg-surface-100/50 dark:hover:bg-surface-800/50'
					)}
				>
					{tab.name === 'all' ? 'All' : tab.name}
				</Tabs.Trigger>
			{/each}

			{#if hasOverflow}
				<div class="relative">
					<button
						type="button"
						onclick={toggleMore}
						class="px-4 py-2 text-sm font-medium text-surface-700 dark:text-surface-300 hover:text-surface-950 dark:text-surface-50 rounded-lg flex items-center gap-1 cursor-pointer hover:bg-surface-100/50 dark:hover:bg-surface-800/50 transition-colors"
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
							class="absolute top-full left-0 mt-2 bg-surface-50 dark:bg-surface-950 rounded-xl shadow-lg border border-surface-200 dark:border-surface-700 py-1 min-w-[140px] z-50"
							role="menu"
						>
							{#each overflowTabs as tab (tab.name)}
								<button
									type="button"
									role="menuitem"
									onclick={() => selectTab(tab.name)}
									class={cn(
										'w-full px-4 py-2.5 text-sm text-left cursor-pointer transition-colors',
									activeTab === tab.name
										?
											'text-white font-medium bg-[var(--color-primary-500,#334155)]'
											: 'text-surface-700 dark:text-surface-300 hover:bg-surface-100 dark:hover:bg-surface-800'
									)}
								>
									{tab.name === 'all' ? 'All' : tab.name}
								</button>
							{/each}
						</div>
					{/if}
				</div>
			{/if}
		</Tabs.List>
	</Tabs>

	{#if showMore}
		<button
			class="fixed inset-0 z-40"
			onclick={() => showMore = false}
			aria-label="Close dropdown"
		></button>
	{/if}
{/if}
