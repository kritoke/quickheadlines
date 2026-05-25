<script lang="ts">
	/**
	 * SkeletonLoader - Animated placeholder during loading
	 * 
	 * Features:
	 * - Shimmer animation from left to right
	 * - Matches dark/light mode
	 * - Multiple variants for different content types
	 * - Accessible: aria-busy="true" on container
	 */

	interface Props {
		variant?: 'feed' | 'timeline-item' | 'text' | 'card';
		lines?: number;
		class?: string;
	}

	let { variant = 'text', lines = 3, class: className = '' }: Props = $props();
</script>

<div 
	class="skeleton-loader {variant} {className}"
	aria-busy="true"
	aria-label="Loading content"
	role="status"
>
	{#if variant === 'feed'}
		<!-- Feed skeleton: header + items -->
		<div class="skeleton-feed">
			<div class="skeleton-header">
				<div class="skeleton-icon"></div>
				<div class="skeleton-title"></div>
			</div>
			<div class="skeleton-items">
				{#each Array(5) as _, i}
					<div class="skeleton-item" style="animation-delay: {i * 0.1}s">
						<div class="skeleton-line" style="width: {70 + Math.random() * 30}%"></div>
					</div>
				{/each}
			</div>
		</div>
	{:else if variant === 'timeline-item'}
		<!-- Timeline item skeleton -->
		<div class="skeleton-timeline-item">
			<div class="skeleton-meta">
				<div class="skeleton-icon"></div>
				<div class="skeleton-badge"></div>
			</div>
			<div class="skeleton-content">
				<div class="skeleton-line" style="width: 90%"></div>
				<div class="skeleton-line" style="width: 60%"></div>
			</div>
			<div class="skeleton-footer">
				<div class="skeleton-time"></div>
			</div>
		</div>
	{:else if variant === 'card'}
		<!-- Card skeleton -->
		<div class="skeleton-card">
			<div class="skeleton-card-header"></div>
			<div class="skeleton-card-body">
				<div class="skeleton-line" style="width: 85%"></div>
				<div class="skeleton-line" style="width: 70%"></div>
				<div class="skeleton-line" style="width: 50%"></div>
			</div>
		</div>
	{:else}
		<!-- Text skeleton with configurable lines -->
		<div class="skeleton-text">
			{#each Array(lines) as _, i}
				<div 
					class="skeleton-line" 
					style="width: {i === lines - 1 ? '60%' : '100%'}; animation-delay: {i * 0.1}s"
				></div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.skeleton-loader {
		--skeleton-bg: #e5e7eb;
		--skeleton-shine: #f3f4f6;
	}

	:global(.dark) .skeleton-loader {
		--skeleton-bg: #374151;
		--skeleton-shine: #4b5563;
	}

	.skeleton-line,
	.skeleton-icon,
	.skeleton-title,
	.skeleton-badge,
	.skeleton-time,
	.skeleton-header,
	.skeleton-meta,
	.skeleton-content,
	.skeleton-footer,
	.skeleton-card-header,
	.skeleton-card-body,
	.skeleton-item {
		background: linear-gradient(
			90deg,
			var(--skeleton-bg) 0%,
			var(--skeleton-shine) 50%,
			var(--skeleton-bg) 100%
		);
		background-size: 200% 100%;
		animation: shimmer 1.5s infinite;
		border-radius: var(--radius-md, 0.5rem);
	}

	@keyframes shimmer {
		0% {
			background-position: 200% 0;
		}
		100% {
			background-position: -200% 0;
		}
	}

	/* Feed variant */
	.skeleton-feed {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-sm, 0.5rem);
	}

	.skeleton-header {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
		padding: var(--spacing-sm, 0.5rem);
	}

	.skeleton-icon {
		width: 1.5rem;
		height: 1.5rem;
		border-radius: var(--radius-full, 9999px);
		flex-shrink: 0;
	}

	.skeleton-title {
		height: 1rem;
		width: 40%;
	}

	.skeleton-items {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-xs, 0.25rem);
		padding: 0 var(--spacing-sm, 0.5rem);
	}

	.skeleton-item {
		padding: var(--spacing-xs, 0.25rem) 0;
	}

	/* Timeline item variant */
	.skeleton-timeline-item {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-sm, 0.5rem);
		padding: var(--spacing-md, 1rem);
		border-radius: var(--radius-lg, 0.75rem);
		border: 1px solid;
		border-color: var(--color-surface-200, #e5e7eb);
	}

	:global(.dark) .skeleton-timeline-item {
		border-color: var(--color-surface-700, #374151);
		background-color: var(--color-surface-900, #111827);
	}

	.skeleton-meta {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
	}

	.skeleton-badge {
		height: 1.25rem;
		width: 5rem;
		margin-left: auto;
	}

	.skeleton-content {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-xs, 0.25rem);
	}

	.skeleton-footer {
		display: flex;
		justify-content: flex-start;
	}

	.skeleton-time {
		height: 0.875rem;
		width: 4rem;
	}

	/* Card variant */
	.skeleton-card {
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.skeleton-card-header {
		height: 4rem;
		border-radius: 0;
	}

	.skeleton-card-body {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-sm, 0.5rem);
		padding: var(--spacing-md, 1rem);
	}

	/* Text variant */
	.skeleton-text {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-sm, 0.5rem);
	}

	.skeleton-line {
		height: 1rem;
	}
</style>
