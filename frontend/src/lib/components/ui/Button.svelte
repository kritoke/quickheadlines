<script lang="ts">
	import { cn } from '$lib/utils';
	import type { HTMLAttributes } from 'svelte/elements';

	type Variant = 'default' | 'secondary' | 'destructive' | 'outline' | 'ghost' | 'link';
	type Size = 'default' | 'sm' | 'lg' | 'icon';

	interface Props extends HTMLAttributes<HTMLButtonElement> {
		variant?: Variant;
		size?: Size;
	}

	let {
		variant = 'default',
		size = 'default',
		class: className,
		children,
		...props
	}: Props = $props();

	const baseStyles = 'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-slate-950 disabled:pointer-events-none disabled:opacity-50 dark:focus-visible:ring-slate-300';

	const variants: Record<Variant, string> = {
		default: 'bg-slate-900 text-slate-50 shadow hover:bg-slate-900/90 dark:bg-slate-50 dark:text-slate-900 dark:hover:bg-slate-50/90',
		secondary: 'bg-slate-100 text-slate-900 shadow-sm hover:bg-slate-100/80 dark:bg-slate-800 dark:text-slate-50 dark:hover:bg-slate-800/80',
		destructive: 'bg-red-500 text-slate-50 shadow-sm hover:bg-red-500/90 dark:bg-red-900 dark:text-slate-50 dark:hover:bg-red-900/90',
		outline: 'border border-slate-200 bg-white shadow-sm hover:bg-slate-100 hover:text-slate-900 dark:border-slate-800 dark:bg-slate-950 dark:hover:bg-slate-800 dark:hover:text-slate-50',
		ghost: 'hover:bg-slate-100 hover:text-slate-900 dark:hover:bg-slate-800 dark:hover:text-slate-50',
		link: 'text-slate-900 underline-offset-4 hover:underline dark:text-slate-50'
	};

	const sizes: Record<Size, string> = {
		default: 'h-9 px-4 py-2',
		sm: 'h-8 rounded-md px-3 text-xs',
		lg: 'h-10 rounded-md px-8',
		icon: 'h-9 w-9'
	};
</script>

<button
	class={cn(baseStyles, variants[variant], sizes[size], className)}
	{...props}
>
	{#if children}
		{@render children()}
	{/if}
</button>
