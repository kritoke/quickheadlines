<script lang="ts">
	import { fade } from 'svelte/transition';
	import type { ToastMessage } from '$lib/stores/toast.svelte';

	const HIGHLIGHTED_TYPES = new Set(['error', 'success', 'warning', 'info']);

	interface Props {
		toast: ToastMessage;
		onClose: (id: string) => void;
	}

	let { toast, onClose }: Props = $props();

	function handleClose() {
		onClose(toast.id);
	}
</script>

<div 
	class="pointer-events-auto relative flex w-full max-w-sm items-center justify-between space-x-4 overflow-hidden rounded-lg border p-6 pr-8 shadow-lg bg-surface-50 dark:bg-surface-950 border-surface-200 dark:border-surface-700"
	class:border-primary-500={HIGHLIGHTED_TYPES.has(toast.type)}
	in:fade={{ duration: 300 }}
	out:fade={{ duration: 200 }}
>
	<div class="grid gap-1 flex-1">
		{#if toast.title}
			<div class="text-sm font-medium text-surface-950 dark:text-surface-50">
				{toast.title}
			</div>
		{/if}
		<div class="text-sm text-surface-700 dark:text-surface-300">
			{toast.description}
		</div>
	</div>
	<button 
		onclick={handleClose}
		class="absolute right-2 top-2 rounded-md p-1 text-surface-400 hover:text-surface-600 dark:hover:text-surface-200 transition-colors"
		aria-label="Close notification"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
			<line x1="18" y1="6" x2="6" y2="18" />
			<line x1="6" y1="6" x2="18" y2="18" />
		</svg>
	</button>
</div>