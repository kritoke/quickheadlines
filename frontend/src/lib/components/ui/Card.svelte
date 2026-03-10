<script lang="ts">
	import { cn } from '$lib/utils';
	import type { HTMLAttributes } from 'svelte/elements';

	interface Props extends HTMLAttributes<HTMLDivElement> {
		variant?: 'default' | 'secondary' | 'muted';
		themeVariant?: boolean;
	}

	let {
		variant = 'default',
		themeVariant = false,
		class: className,
		children,
		...props
	}: Props = $props();

	const baseStyles = 'rounded-lg border text-card-foreground';

	const variants = {
		default: 'bg-white text-slate-950 shadow-sm dark:bg-slate-950 dark:text-slate-50 border-slate-200 dark:border-slate-800',
		secondary: 'bg-slate-100 text-slate-900 dark:bg-slate-800 dark:text-slate-50 border-slate-200 dark:border-slate-700',
		muted: 'bg-slate-50 text-slate-900 dark:bg-slate-800/50 dark:text-slate-50 border-slate-200 dark:border-slate-700'
	};

	const themeStyles = 'bg-[var(--theme-bg)] text-[var(--theme-text)] border-[var(--theme-border)] shadow-[var(--theme-shadow)]';
</script>

<div 
	data-name="card" 
	class={cn(baseStyles, themeVariant ? themeStyles : variants[variant], className)} 
	{...props}
>
	{#if children}
		{@render children()}
	{/if}
</div>
