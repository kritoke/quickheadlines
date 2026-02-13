<script lang="ts">
	import { cn } from '$lib/utils';
	import type { HTMLAttributes } from 'svelte/elements';

	interface Props extends HTMLAttributes<HTMLAnchorElement> {
		href?: string;
	}

	let { class: className, children, href = '#', ...props }: Props = $props();
</script>

<a
	href={href}
	class={cn('transition-colors hover:text-slate-900 dark:hover:text-slate-50', className)}
	{...props}
>
	{#if children}
		{@render children()}
	{/if}
</a>
