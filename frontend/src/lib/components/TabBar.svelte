<script lang="ts">
	import type { TabResponse } from '$lib/types';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		onTabChange: (tab: string) => void;
	}

	let { tabs, activeTab, onTabChange }: Props = $props();

	let navElement: HTMLElement | undefined = $state();
	let allButton: HTMLButtonElement | undefined = $state();

	function scrollToActiveTab() {
		if (!navElement) return;
		
		const activeBtn = navElement.querySelector('.tab-active') as HTMLElement | null;
		if (!activeBtn) return;
		
		const navRect = navElement.getBoundingClientRect();
		const btnRect = activeBtn.getBoundingClientRect();
		
		const btnCenter = btnRect.left + btnRect.width / 2;
		const navCenter = navRect.left + navRect.width / 2;
		const scrollOffset = btnCenter - navCenter;
		
		navElement.scrollBy({ left: scrollOffset, behavior: 'smooth' });
	}

	$effect(() => {
		activeTab;
		scrollToActiveTab();
	});
</script>

<nav 
	class="tab-bar sticky top-16 z-20 bg-white dark:bg-slate-900 flex gap-1 p-2 overflow-x-auto"
	bind:this={navElement}
>
	<button
		bind:this={allButton}
		onclick={() => onTabChange('all')}
		class="tab px-3 py-1.5 text-sm font-medium rounded-md whitespace-nowrap transition-colors
			{activeTab === 'all'
			? 'tab-active bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm'
			: 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}"
	>
		All
	</button>
	
	{#each tabs as tab (tab.name)}
		<button
			onclick={() => onTabChange(tab.name)}
			class="tab px-3 py-1.5 text-sm font-medium rounded-md whitespace-nowrap transition-colors
				{activeTab === tab.name
				? 'tab-active bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm'
				: 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}"
		>
			{tab.name}
		</button>
	{/each}
</nav>
