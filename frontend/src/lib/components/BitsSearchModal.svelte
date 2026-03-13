<script lang="ts">
	import { Dialog } from 'bits-ui';

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
			inputEl.focus();
		}
	});

	function handleInputKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			onClose();
		}
	}
</script>

<Dialog.Root open={open} onOpenChange={(open) => !open && onClose()}>
	<Dialog.Portal>
		<Dialog.Overlay class="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm" />
		
		<Dialog.Content class="fixed top-0 left-0 right-0 z-50 theme-bg-primary shadow-xl theme-border">
			<div class="mx-auto py-4 px-4 md:px-8 xl:px-12" style="max-width: 1400px;">
				<div class="flex items-center gap-3 max-w-md mx-auto">
					<div class="relative flex-1">
						<input 
							bind:this={inputEl}
							value={query}
							oninput={(e) => onQueryChange(e.currentTarget.value)}
							onkeydown={handleInputKeydown}
							{placeholder}
							class="w-full px-4 py-3 text-base theme-bg-secondary theme-border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 theme-text-primary placeholder-slate-400"
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
		</Dialog.Content>
	</Dialog.Portal>
</Dialog.Root>