<script lang="ts">
	import type { TabResponse } from '$lib/types';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		onTabChange: (tab: string) => void;
	}

	let { tabs, activeTab, onTabChange }: Props = $props();
</script>

<nav class="tab-bar flex gap-1 p-2 bg-slate-100 dark:bg-slate-800 rounded-lg mb-4 overflow-x-auto">
	<button
		onclick={() => onTabChange('all')}
		class="tab px-3 py-1.5 text-sm font-medium rounded-md whitespace-nowrap transition-colors
			{activeTab === 'all'
			? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm'
			: 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}"
	>
		All
	</button>
	
	{#each tabs as tab (tab.name)}
		<button
			onclick={() => onTabChange(tab.name)}
			class="tab px-3 py-1.5 text-sm font-medium rounded-md whitespace-nowrap transition-colors
				{activeTab === tab.name
				? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm'
				: 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}"
		>
			{tab.name}
		</button>
	{/each}
</nav>
