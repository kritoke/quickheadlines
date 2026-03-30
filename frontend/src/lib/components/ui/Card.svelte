<script lang="ts">
	import { cn } from '$lib/utils';
	import type { HTMLAttributes } from 'svelte/elements';

	interface Props extends HTMLAttributes<HTMLDivElement> {
		headerColor?: string;
		headerBgColor?: string;
	}

	let {
		headerColor,
		headerBgColor,
		class: className,
		children,
		style,
		...props
	}: Props = $props();

	const baseStyles = 'rounded-2xl border transition-shadow duration-200';

	function getStyle(): string | undefined {
		const styles: string[] = [];
		
		if (headerBgColor) {
			styles.push(`background-color: ${headerBgColor}`);
		} else {
			styles.push('background-color: var(--color-bg-primary, var(--theme-bg))');
		}
		
		if (headerColor) {
			styles.push(`color: ${headerColor}`);
		}
		
		if (style) {
			styles.push(style);
		}
		
		return styles.length > 0 ? styles.join('; ') : undefined;
	}
</script>

<div 
	data-name="card" 
	class={cn(baseStyles, 'theme-border', className)} 
	style={getStyle()}
	{...props}
>
	{#if children}
		{@render children()}
	{/if}
</div>