<script lang="ts">
	import { Dialog, Portal } from '@skeletonlabs/skeleton-svelte';
	import { searchState, closeSearch, setSearchQuery } from '$lib/stores/search.svelte';

	interface Props {
		placeholder: string;
	}

	let { placeholder }: Props = $props();
	let inputEl: HTMLInputElement | undefined = $state();
	let isOpen = $state(false);

	$effect(() => {
		isOpen = searchState.expanded;
	});

	$effect(() => {
		if (isOpen && inputEl) {
			setTimeout(() => inputEl?.focus(), 0);
		}
	});

	function handleOpenChange(val: { open: boolean }) {
		if (!val.open) closeSearch();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			closeSearch();
		} else if (e.key === 'Enter') {
			e.preventDefault();
			closeSearch();
		}
	}
</script>

<Dialog open={isOpen} onOpenChange={handleOpenChange}>
	<Portal>
		<Dialog.Backdrop class="fixed inset-0 z-40 bg-surface-950/50 backdrop-blur-sm" />
		<Dialog.Positioner class="fixed inset-0 z-50 flex justify-center items-start">
			<Dialog.Content class="card bg-surface-100-900 w-full shadow-xl mt-0">
				<div class="mx-auto px-4 py-4 md:px-8 xl:px-12" style="max-width: 1400px;">
					<div class="flex items-center gap-3 max-w-md mx-auto">
						<div class="relative flex-1">
							<input 
								bind:this={inputEl}
								value={searchState.query}
								oninput={(e) => setSearchQuery(e.currentTarget.value)}
								onkeydown={handleKeydown}
								{placeholder}
								class="w-full px-4 py-3 text-base bg-surface-200 dark:bg-surface-800 border border-surface-300 dark:border-surface-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 text-surface-950 dark:text-surface-50 placeholder-surface-400"
							/>
							{#if searchState.query}
								<button 
									onclick={() => setSearchQuery('')} 
									class="absolute right-3 top-1/2 -translate-y-1/2 text-surface-400 hover:text-surface-600 dark:hover:text-surface-300"
									aria-label="Clear search"
								>
									<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							{/if}
						</div>
						
						<button 
							onclick={closeSearch}
							class="btn-icon hover:preset-tonal"
							aria-label="Close search"
						>
							<svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
								<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					</div>
				</div>
			</Dialog.Content>
		</Dialog.Positioner>
	</Portal>
</Dialog>
