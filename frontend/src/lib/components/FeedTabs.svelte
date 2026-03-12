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
	let hasOverflow = $state(true);

	const allTabs = $derived([{ name: 'all' }, ...tabs]);

	function updateScrollButtons() {
		if (!listElement) return;
		hasOverflow = listElement.scrollWidth > listElement.clientWidth + 4;
	}

	function scrollLeft() {
		if (!listElement) return;
		listElement.scrollBy({ left: -150, behavior: 'smooth' });
	}

	function scrollRight() {
		if (!listElement) return;
		listElement.scrollBy({ left: 150, behavior: 'smooth' });
	}

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
		if (listElement) {
			const el = listElement;
			el.addEventListener('scroll', updateScrollButtons);
			const ro = new ResizeObserver(updateScrollButtons);
			ro.observe(el);
			return () => {
				el.removeEventListener('scroll', updateScrollButtons);
				ro.disconnect();
			};
		}
	});

	$effect(() => {
		if (activeTab) {
			scrollToActiveTab();
		}
	});
</script>

<Tabs.Root
	value={activeTab}
	class="w-full z-20 mb-4 mt-3 sm:mt-6"
	data-name="feed-tabs"
	onValueChange={(newValue) => {
		if (newValue && newValue !== activeTab) {
			onTabChange(newValue);
		}
	}}
>
	<div class="max-w-[1400px] mx-auto">
		<div
			bind:this={listElement}
			class="sticky top-16 z-20 flex items-center gap-1 px-8 overflow-x-auto scroll-smooth scrollbar-hide rounded-xl shadow-sm bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
		>
			{#if hasOverflow}
				<button
					type="button"
					onclick={scrollLeft}
					class="shrink-0 w-6 h-6 flex items-center justify-center rounded-full bg-slate-200/80 dark:bg-slate-700/80 hover:bg-slate-300 dark:hover:bg-slate-600 backdrop-blur shadow"
					aria-label="Scroll left"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-600 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
					</svg>
				</button>
			{/if}

			{#each allTabs as tab (tab.name)}
				<Tabs.Trigger
					data-name="tab-button"
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
							class="absolute inset-0 rounded-lg -z-10 shadow-sm bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 {themeState.effects ? 'shadow-blue-500/30' : ''}"
							style="view-transition-name: tab-pill;"
						></div>
					{/if}
				</Tabs.Trigger>
			{/each}
			{#if hasOverflow}
				<button
					type="button"
					onclick={scrollRight}
					class="shrink-0 w-6 h-6 flex items-center justify-center rounded-full bg-slate-200/80 dark:bg-slate-700/80 hover:bg-slate-300 dark:hover:bg-slate-600 backdrop-blur shadow"
					aria-label="Scroll right"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-600 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
					</svg>
				</button>
			{/if}
		</div>
	</div>
</Tabs.Root>
