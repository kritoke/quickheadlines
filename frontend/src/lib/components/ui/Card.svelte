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

	const baseStyles = 'rounded-2xl border text-card-foreground bg-white dark:bg-slate-950 transition-shadow duration-200';

	const variants = {
		default: 'shadow-sm border-slate-200/80 dark:border-slate-800/80',
		secondary: 'bg-slate-50 dark:bg-slate-900 border-slate-200 dark:border-slate-800',
		muted: 'bg-slate-100/50 dark:bg-slate-900/50 border-slate-200/50 dark:border-slate-800/50'
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