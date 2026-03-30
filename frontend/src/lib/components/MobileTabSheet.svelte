<script lang="ts">
	import { themeState } from '$lib/stores/theme.svelte';
	import type { TabResponse } from '$lib/types';
	import { spacing } from '$lib/design/tokens';

	interface Props {
		tabs: TabResponse[];
		activeTab: string;
		open: boolean;
		onClose: () => void;
		onTabChange: (tab: string) => void;
	}

	let { tabs, activeTab, open, onClose, onTabChange }: Props = $props();

	function handleBackdropClick() {
		onClose();
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

	$effect(() => {
		if (open) {
			document.body.style.overflow = 'hidden';
		} else {
			document.body.style.overflow = '';
		}

		return () => {
			document.body.style.overflow = '';
		};
	});
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if open}
	<div
		class="fixed inset-0 bg-black/50 z-[100] md:hidden pointer-events-auto"
		onclick={handleBackdropClick}
		onkeydown={(e) => e.key === 'Enter' && handleBackdropClick()}
		role="button"
		tabindex="-1"
		aria-label="Close menu"
	>
		<div
			class="absolute bottom-0 left-0 right-0 theme-bg-primary rounded-t-2xl p-4 animate-slide-up"
			onclick={(e) => { e.preventDefault(); e.stopPropagation(); }}
			onkeydown={(e) => { e.preventDefault(); e.stopPropagation(); }}
			role="dialog"
			aria-modal="true"
			aria-label="Select category"
			tabindex="-1"
		>
			<!-- Drag handle -->
			<div class="w-12 h-1 theme-text-secondary/30 rounded-full mx-auto mb-4"></div>
			
			<h3 class="text-sm font-semibold theme-text-primary mb-3">Select Category</h3>
			
			<div class="space-y-1 max-h-[60vh] overflow-y-auto">
				{#each tabs as tab (tab.name)}
					<button
						onclick={() => selectTab(tab.name)}
						class="w-full px-4 {spacing.spacious} text-left rounded-lg transition-colors
							{activeTab === tab.name 
								? 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 font-medium' 
								: 'hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300'}"
					>
						<span class="capitalize">{tab.name === 'all' ? 'All' : tab.name}</span>
						{#if activeTab === tab.name}
							<svg class="w-5 h-5 inline float-right text-blue-500" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
							</svg>
						{/if}
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

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
