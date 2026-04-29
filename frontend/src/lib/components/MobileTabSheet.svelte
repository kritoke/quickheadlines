<script lang="ts">
	import { Dialog, Portal } from '@skeletonlabs/skeleton-svelte';
	import type { TabResponse } from '$lib/types';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		open: boolean;
		onClose: () => void;
		onTabChange: (tab: string) => void;
	}

	let { tabs, activeTab, open = $bindable(), onClose, onTabChange }: Props = $props();

	function handleOpenChange(e: { open: boolean }) {
		if (!e.open) {
			onClose();
		}
	}

	function handleKeyDown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			onClose();
		}
	}

	function selectTab(tab: string) {
		onTabChange(tab);
		onClose();
	}
</script>

<svelte:window onkeydown={handleKeyDown} />

<Dialog {open} onOpenChange={handleOpenChange}>
	<Portal>
		<Dialog.Backdrop class="fixed inset-0 bg-black/50 z-[100] md:hidden pointer-events-auto" />
		<Dialog.Positioner class="fixed inset-0 z-[101] flex items-end">
			<Dialog.Content class="w-full rounded-t-2xl bg-surface-50 dark:bg-surface-950 p-4 animate-slide-up">
				<!-- Drag handle -->
				<div class="w-12 h-1 text-surface-700/30 dark:text-surface-300/30 rounded-full mx-auto mb-4"></div>
				
				<h3 class="text-sm font-semibold text-surface-950 dark:text-surface-50 mb-3">Select Category</h3>
				
				<div class="space-y-1 max-h-[60vh] overflow-y-auto">
					{#each tabs as tab, i (`tab-${tab.name}-${i}`)}
						<button
							onclick={() => selectTab(tab.name)}
							class="w-full px-4 py-6 text-left rounded-lg transition-colors
								{activeTab === tab.name 
									? 'bg-surface-100 dark:bg-surface-800 text-[var(--color-primary-500,#334155)] font-medium' 
									: 'hover:bg-surface-100 dark:hover:bg-surface-800 text-surface-950 dark:text-surface-50'}"
						>
							<span class="capitalize">{tab.name === 'all' ? 'All' : tab.name}</span>
							{#if activeTab === tab.name}
								<svg class="w-5 h-5 inline float-right text-[var(--color-primary-500,#334155)]" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
								</svg>
							{/if}
						</button>
					{/each}
				</div>
			</Dialog.Content>
		</Dialog.Positioner>
	</Portal>
</Dialog>

<!-- svelte-ignore css_unused_selector -->
<style>
	@keyframes slide-up {
		from {
			transform: translateY(100%);
		}
		to {
			transform: translateY(0);
		}
	}
	.animate-slide-up {
		animation: slide-up 0.3s ease-out;
	}
	@media (prefers-reduced-motion: reduce) {
		.animate-slide-up {
			animation: none;
		}
	}
</style>