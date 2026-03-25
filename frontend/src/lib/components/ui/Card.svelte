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

	const baseStyles = 'rounded-2xl border transition-shadow duration-200 theme-bg-primary theme-border';

	const variants = {
		default: 'shadow-sm',
		secondary: 'theme-bg-secondary',
		muted: ''
	};
</script>

<div 
	data-name="card" 
	class={cn(baseStyles, variants[variant], className)} 
	{...props}
>
	{#if children}
		{@render children()}
	{/if}
</div>