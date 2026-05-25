<script lang="ts">
	import { Dialog, Portal } from '@skeletonlabs/skeleton-svelte';
	import { searchState, closeSearch, setSearchQuery } from '$lib/stores/search.svelte';
	import SkeletonLoader from './SkeletonLoader.svelte';

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

	// Sanitize user input to prevent XSS and injection
	function sanitizeSearchInput(input: string): string {
		return input
			.replace(/[<>\"'&;\\]/g, '') // Remove potentially dangerous characters
			.trim()
			.slice(0, 200); // Limit length to prevent abuse
	}

	function handleInput(value: string) {
		const sanitized = sanitizeSearchInput(value);
		setSearchQuery(sanitized);
	}
</script>

<Dialog open={isOpen} onOpenChange={handleOpenChange}>
	<Portal>
		<Dialog.Backdrop class="dialog-backdrop" />
		<Dialog.Positioner class="dialog-positioner">
			<Dialog.Content class="dialog-content">
				<div class="dialog-inner">
					<div class="search-container">
						<div class="search-input-wrapper">
							<input 
								bind:this={inputEl}
								value={searchState.query}
								oninput={(e) => handleInput(e.currentTarget.value)}
								onkeydown={handleKeydown}
								{placeholder}
								class="search-input"
							/>
							{#if searchState.query}
								<button 
									onclick={() => setSearchQuery('')} 
									class="clear-button"
									aria-label="Clear search"
								>
									<svg xmlns="http://www.w3.org/2000/svg" class="clear-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							{/if}
						</div>
						
						<button 
							onclick={closeSearch}
							class="close-button"
							aria-label="Close search"
						>
							<svg xmlns="http://www.w3.org/2000/svg" class="close-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
								<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					</div>
				</div>
			</Dialog.Content>
		</Dialog.Positioner>
	</Portal>
</Dialog>

<style>
	.dialog-backdrop {
		position: fixed;
		inset: 0;
		background-color: rgb(0 0 0 / 0.5);
		backdrop-filter: blur(4px);
		z-index: 40;
	}

	.dialog-positioner {
		position: fixed;
		inset: 0;
		display: flex;
		justify-content: center;
		align-items: flex-start;
		z-index: 50;
		padding-top: 0;
	}

	.dialog-content {
		background-color: var(--color-surface-100, #f3f4f6);
		width: 100%;
		box-shadow: var(--shadow-xl, 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1));
	}

	:global(.dark) .dialog-content {
		background-color: var(--color-surface-900, #111827);
	}

	.dialog-inner {
		margin: 0 auto;
		padding: var(--spacing-md, 1rem) var(--spacing-lg, 1.5rem);
	}

	@media (min-width: 768px) {
		.dialog-inner {
			padding: var(--spacing-lg, 1.5rem) var(--spacing-2xl, 3rem);
		}
	}

	@media (min-width: 1280px) {
		.dialog-inner {
			padding-left: var(--spacing-3xl, 4rem);
			padding-right: var(--spacing-3xl, 4rem);
		}
	}

	.search-container {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
		max-width: 32rem;
		margin: 0 auto;
	}

	.search-input-wrapper {
		position: relative;
		flex: 1;
	}

	.search-input {
		width: 100%;
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
		font-size: 1rem;
		line-height: 1.5;
		background-color: var(--color-surface-200, #e5e7eb);
		border: 1px solid var(--color-surface-300, #d1d5db);
		border-radius: var(--radius-md, 0.5rem);
		outline: none;
		transition: box-shadow 0.15s ease;
	}

	:global(.dark) .search-input {
		background-color: var(--color-surface-800, #1f2937);
		border-color: var(--color-surface-700, #374151);
		color: var(--color-surface-50, #f9fafb);
	}

	.search-input:focus {
		box-shadow: 0 0 0 2px var(--color-primary-500, #3b82f6);
	}

	.search-input::placeholder {
		color: var(--color-surface-400, #9ca3af);
	}

	.clear-button {
		position: absolute;
		right: 0.75rem;
		top: 50%;
		transform: translateY(-50%);
		padding: 0.25rem;
		color: var(--color-surface-400, #9ca3af);
		background: none;
		border: none;
		cursor: pointer;
		transition: color 0.15s ease;
	}

	.clear-button:hover {
		color: var(--color-surface-600, #4b5563);
	}

	:global(.dark) .clear-button:hover {
		color: var(--color-surface-300, #d1d5db);
	}

	.clear-icon {
		width: 1.25rem;
		height: 1.25rem;
	}

	.close-button {
		padding: 0.5rem;
		border-radius: var(--radius-md, 0.5rem);
		color: var(--color-surface-600, #4b5563);
		background: none;
		border: none;
		cursor: pointer;
		transition: background-color 0.15s ease;
	}

	:global(.dark) .close-button {
		color: var(--color-surface-300, #d1d5db);
	}

	.close-button:hover {
		background-color: var(--color-surface-200, #e5e7eb);
	}

	:global(.dark) .close-button:hover {
		background-color: var(--color-surface-800, #1f2937);
	}

	.close-icon {
		width: 1.5rem;
		height: 1.5rem;
	}
</style>
