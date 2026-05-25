<script lang="ts">
	/**
	 * EmptyState - Delightful empty state with icon, title, description, and optional action
	 * 
	 * Usage:
	 * <EmptyState 
	 *   title="No feeds found" 
	 *   description="Check your configuration"
	 * >
	 *   {#snippet action()}
	 *     <button onclick={handleRetry}>Retry</button>
	 *   {/snippet}
	 * </EmptyState>
	 */

	import type { Snippet } from 'svelte';

	interface Props {
		title: string;
		description?: string;
		icon?: Snippet;
		action?: Snippet;
		class?: string;
	}

	let { title, description, icon, action, class: className = '' }: Props = $props();
</script>

<div class="empty-state {className}" role="status">
	{#if icon}
		<div class="empty-state-icon">
			{@render icon()}
		</div>
	{:else}
		<div class="empty-state-icon default-icon">
			<svg 
				xmlns="http://www.w3.org/2000/svg" 
				width="48" 
				height="48" 
				viewBox="0 0 24 24" 
				fill="none" 
				stroke="currentColor" 
				stroke-width="1.5" 
				stroke-linecap="round" 
				stroke-linejoin="round"
			>
				<circle cx="12" cy="12" r="10"></circle>
				<line x1="12" y1="8" x2="12" y2="12"></line>
				<line x1="12" y1="16" x2="12.01" y2="16"></line>
			</svg>
		</div>
	{/if}

	<div class="empty-state-content">
		<h3 class="empty-state-title">{title}</h3>
		
		{#if description}
			<p class="empty-state-description">{description}</p>
		{/if}

		{#if action}
			<div class="empty-state-action">
				{@render action()}
			</div>
		{/if}
	</div>
</div>

<style>
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: var(--spacing-2xl, 3rem) var(--spacing-lg, 1.5rem);
		min-height: 16rem;
	}

	.empty-state-icon {
		margin-bottom: var(--spacing-lg, 1.5rem);
		color: var(--color-surface-400, #9ca3af);
	}

	.empty-state-icon :global(svg) {
		width: 3rem;
		height: 3rem;
	}

	.empty-state-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
		max-width: 24rem;
	}

	.empty-state-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: var(--color-surface-700, #374151);
		margin: 0;
	}

	:global(.dark) .empty-state-title {
		color: var(--color-surface-200, #e5e7eb);
	}

	.empty-state-description {
		font-size: 0.875rem;
		color: var(--color-surface-500, #6b7280);
		margin: 0;
		line-height: 1.5;
	}

	:global(.dark) .empty-state-description {
		color: var(--color-surface-400, #9ca3af);
	}

	.empty-state-action {
		margin-top: var(--spacing-md, 1rem);
	}

	.empty-state-action :global(button) {
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
		border-radius: var(--radius-md, 0.5rem);
		font-weight: 500;
		transition: all 0.15s ease;
	}

	.empty-state-action :global(button:hover) {
		opacity: 0.9;
		transform: translateY(-1px);
	}

	.empty-state-action :global(button:active) {
		transform: translateY(0);
	}
</style>
