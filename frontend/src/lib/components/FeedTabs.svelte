<script lang="ts">
	import { Tabs } from 'bits-ui';
	import { fly } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';
	import { themeState } from '$lib/stores/theme.svelte';
	import type { TabResponse } from '$lib/types';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		onTabChange: (tab: string) => void;
	}

	let { tabs, activeTab, onTabChange }: Props = $props();

	let listElement: HTMLDivElement | undefined = $state();

	const allTabs = $derived([{ name: 'all' }, ...tabs]);

	function scrollToActiveTab() {
		if (!listElement) return;

		const activeBtn = listElement.querySelector('[data-state="active"]') as HTMLElement | null;
		if (!activeBtn) return;

		const listRect = listElement.getBoundingClientRect();
		const btnRect = activeBtn.getBoundingClientRect();

		const btnCenter = btnRect.left + btnRect.width / 2;
		const listCenter = listRect.left + listRect.width / 2;
		const scrollOffset = btnCenter - listCenter;

		listElement.scrollBy({ left: scrollOffset, behavior: 'smooth' });
	}

	$effect(() => {
		if (activeTab) {
			scrollToActiveTab();
		}
	});
</script>

<Tabs.Root
	value={activeTab}
	class="w-full z-20 my-3"
	onValueChange={(newValue) => {
		if (newValue && newValue !== activeTab) {
			onTabChange(newValue);
		}
	}}
>
	<div
		bind:this={listElement}
		class="relative flex items-center gap-1 p-1 overflow-x-auto
			bg-slate-100/80 dark:bg-slate-800/80 backdrop-blur-xl
			rounded-xl border border-slate-200/50 dark:border-slate-700/50
			shadow-sm"
	>
		{#each allTabs as tab (tab.name)}
			<Tabs.Trigger
				value={tab.name}
				class="relative px-3 py-1.5 text-sm font-medium whitespace-nowrap
					transition-colors duration-300 z-10 rounded-lg
					data-[state=active]:text-slate-900 dark:data-[state=active]:text-white
					text-slate-500 dark:text-slate-400
					hover:text-slate-700 dark:hover:text-slate-300
					focus:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2"
			>
				<span class="relative z-20">{tab.name === 'all' ? 'All' : tab.name}</span>

				{#if activeTab === tab.name}
					<div
						in:fly={{ x: 5, duration: 300, easing: cubicOut }}
						class="absolute inset-0 rounded-lg -z-10
							bg-white dark:bg-slate-700
							border border-slate-200 dark:border-slate-600
							shadow-sm
							{themeState.coolMode
							? 'shadow-luxe-glow border-accent/30'
							: ''}"
						style="view-transition-name: tab-pill;"
					></div>
				{/if}
			</Tabs.Trigger>
		{/each}
	</div>
</Tabs.Root>
