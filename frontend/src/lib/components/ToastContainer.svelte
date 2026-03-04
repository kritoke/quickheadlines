<script lang="ts">
	import { toastStore } from '$lib/stores/toast.svelte';
	import Toast from './Toast.svelte';
</script>

<div class="pointer-events-none fixed top-4 right-4 z-[100] flex max-h-screen w-full flex-col-reverse gap-2 p-4 sm:max-w-sm md:max-w-md">
	{#each toastStore.toasts as toast (toast.id)}
		<Toast 
			toast={toast}
			onClose={(id) => toastStore.remove(id)}
		/>
	{/each}
</div>