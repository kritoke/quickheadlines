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

	let { tabs, activeTab = $bindable(), onTabChange }: Props = $props();

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
		activeTab;
		scrollToActiveTab();
	});

	function handleTabChange(newValue: string) {
		if (newValue && newValue !== activeTab) {
			onTabChange(newValue);
		}
	}
</script>

<Tabs.Root
	bind:value={activeTab}
	class="w-full sticky top-16 z-20"
	onValueChange={handleTabChange}
>
	<div
		bind:this={listElement}
		class="relative flex items-center gap-1 p-1.5 overflow-x-auto
			bg-white/50 dark:bg-zinc-950/50 backdrop-blur-2xl
			rounded-2xl border border-zinc-200/50 dark:border-zinc-800/50
			shadow-[inset_0_1px_2px_rgba(0,0,0,0.05)]
			dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]"
	>
		{#each allTabs as tab (tab.name)}
			<Tabs.Trigger
				value={tab.name}
				class="relative px-4 py-2 text-sm font-medium whitespace-nowrap
					transition-colors duration-300 z-10 rounded-xl
					data-[state=active]:text-zinc-950 dark:data-[state=active]:text-white
					text-zinc-500 dark:text-zinc-400
					hover:text-zinc-700 dark:hover:text-zinc-200
					focus:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2"
			>
				<span class="relative z-20">{tab.name === 'all' ? 'All' : tab.name}</span>

				{#if activeTab === tab.name}
					<div
						in:fly={{ x: 5, duration: 300, easing: cubicOut }}
						class="absolute inset-0 rounded-xl -z-10
							bg-white dark:bg-zinc-800
							border border-zinc-200 dark:border-zinc-700/50
							shadow-sm
							{themeState.cursorTrail
							? 'shadow-[0_0_15px_-3px_rgba(150,173,141,0.4)] border-accent/40'
							: ''}"
						style="view-transition-name: tab-pill;"
					></div>
				{/if}
			</Tabs.Trigger>
		{/each}
	</div>
</Tabs.Root>
