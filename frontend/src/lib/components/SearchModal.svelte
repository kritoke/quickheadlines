<script lang="ts">
	import { fade, fly } from 'svelte/transition';
	import { tick } from 'svelte';

	interface Props {
		open: boolean;
		query: string;
		placeholder: string;
		onClose: () => void;
		onQueryChange: (value: string) => void;
	}

	let { open, query, placeholder, onClose, onQueryChange }: Props = $props();
	let inputEl: HTMLInputElement | undefined = $state();

	$effect(() => {
		if (open && inputEl) {
			tick().then(() => inputEl?.focus());
		}
	});

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && open) {
			onClose();
		}
	}

	function handleInputKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			onClose();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<div 
		class="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm"
		onclick={onClose}
		in:fade={{ duration: 150 }}
		out:fade={{ duration: 150 }}
		role="presentation"
	></div>
	
	<div 
		class="fixed top-0 left-0 right-0 z-50 bg-white dark:bg-slate-900 shadow-xl border-b border-slate-200 dark:border-slate-700"
		in:fly={{ y: -50, duration: 200 }}
		out:fly={{ y: -50, duration: 200 }}
		role="dialog"
		aria-label="Search"
	>
		<div class="mx-auto py-4 px-4 md:px-8 xl:px-12" style="max-width: 1800px;">
			<div class="flex items-center gap-3 max-w-md mx-auto">
				<div class="relative flex-1">
					<input 
						bind:this={inputEl}
						value={query}
						oninput={(e) => onQueryChange(e.currentTarget.value)}
						onkeydown={handleInputKeydown}
						{placeholder}
						class="w-full px-4 py-3 text-base bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500"
					/>
					{#if query}
						<button 
							onclick={() => onQueryChange('')} 
							class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
							aria-label="Clear search"
						>
							<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
								<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					{/if}
				</div>
				
				<button 
					onclick={onClose}
					class="p-2 text-slate-500 hover:text-slate-700 dark:hover:text-slate-300 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
					aria-label="Close search"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>
		</div>
	</div>
{/if}
