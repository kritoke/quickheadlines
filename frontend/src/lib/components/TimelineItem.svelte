<script lang="ts">
	import type { TimelineItemResponse } from '#lib/types';
	import { formatTimestamp } from '#lib/api';
	import ClusterExpansion from './ClusterExpansion.svelte';
	import { readModeState } from '#lib/stores/readMode.svelte';
	import { goto } from '$app/navigation';
	import { getFaviconSrc, getHeaderStyle } from '#lib/utils/feedItem';
	import { sanitizeUrl } from '#lib/utils/validation';
	import CommentIcon from './icons/CommentIcon.svelte';
	import DiscussionIcon from './icons/DiscussionIcon.svelte';

	interface Props {
		item: TimelineItemResponse;
		isDark: boolean;
		expanded: boolean;
		clusterItems: TimelineItemResponse[];
		clusterLoading?: boolean;
		clusterError?: boolean;
		onToggle: () => void;
		onRetry: () => void;
	}

	let {
		item,
		isDark,
		expanded,
		clusterItems,
		clusterLoading,
		clusterError,
		onToggle,
		onRetry
	}: Props = $props();
</script>

<div
	class="timeline-item"
>
	<!-- Item Header with Feed Info -->
	<div
		class="item-header"
		style={getHeaderStyle(item, isDark)}
	>
		<div class="favicon-wrapper">
			<img
				src={getFaviconSrc(item)}
				alt="{item.feed_title} favicon"
				class="favicon"
				onerror={(e) => {
					const target = e.target as HTMLImageElement;
					target.src = '/favicon.svg';
				}}
			/>
		</div>
		<span class="feed-title truncate">{item.feed_title}</span>
		{#if item.cluster_size && item.cluster_size > 1}
			<button
				type="button"
				onclick={onToggle}
				class="cluster-button"
				aria-label="Show {item.cluster_size} similar stories"
			>
				{item.cluster_size} sources
				{#if expanded}
					<svg xmlns="http://www.w3.org/2000/svg" class="chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
					</svg>
				{:else}
					<svg xmlns="http://www.w3.org/2000/svg" class="chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
					</svg>
				{/if}
			</button>
		{/if}
	</div>
	
	<!-- Item Content -->
	<div class="item-content">
		{#if readModeState.mode === 'read'}
			<button
				type="button"
				onclick={() => {
					const params = new URLSearchParams({
						url: item.link,
						title: item.title
					});
					goto(`/reader?${params.toString()}`);
				}}
				class="read-mode-link"
			>
				<h3 class="item-title">{item.title}</h3>
			</button>
		{:else}
			<h3 class="item-title">
				<a
					href={sanitizeUrl(item.link)}
					target="_blank"
					rel="noopener noreferrer"
					class="title-link"
				>{item.title}</a>
			</h3>
		{/if}
		<div class="item-meta">
			<span class="timestamp">
				{formatTimestamp(item.pub_date)}
			</span>
			{#if item.comment_url}
				<a
					href={sanitizeUrl(item.comment_url)}
					target="_blank"
					rel="noopener noreferrer"
					title="Comments"
					class="icon-link"
				>
					<CommentIcon class="w-4 h-4" />
				</a>
			{/if}
			{#if item.commentary_url && item.commentary_url !== item.comment_url}
				<a
					href={sanitizeUrl(item.commentary_url)}
					target="_blank"
					rel="noopener noreferrer"
					title="Discussion"
					class="icon-link"
				>
					<DiscussionIcon class="w-4 h-4" />
				</a>
			{/if}
		</div>
	</div>

	<!-- Cluster Expansion -->
	{#if expanded && item.cluster_id}
		<ClusterExpansion
			items={clusterItems}
			loading={clusterLoading}
			error={clusterError}
			{onRetry}
		/>
	{/if}
</div>

<style>
	.timeline-item {
		display: flex;
		flex-direction: column;
		border-radius: var(--radius-lg, 0.75rem);
		border: 1px solid var(--color-surface-200, #e5e7eb);
		background-color: var(--color-surface-50, #f9fafb);
		overflow: hidden;
		transition: all 0.2s ease;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
	}

	:global(.dark) .timeline-item {
		border-color: var(--color-surface-700, #374151);
		background-color: var(--color-surface-900, #111827);
	}

	.item-header {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
		font-size: 0.75rem;
		font-weight: 500;
	}

	.favicon-wrapper {
		width: 1rem;
		height: 1rem;
		border-radius: var(--radius-sm, 0.125rem);
		padding: 0.125rem;
		background-color: rgb(255 255 255 / 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	:global(.dark) .favicon-wrapper {
		background-color: rgb(255 255 255 / 0.7);
	}

	.favicon {
		width: 0.75rem;
		height: 0.75rem;
		border-radius: var(--radius-sm, 0.125rem);
	}

	.feed-title {
		font-size: 0.75rem;
	}

	.cluster-button {
		margin-left: auto;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		border-radius: var(--radius-sm, 0.125rem);
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.15s ease;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		background-color: rgb(51 65 85 / 0.2);
		border: none;
	}

	.cluster-button:hover {
		background-color: rgb(51 65 85 / 0.3);
	}

	.cluster-button:active {
		background-color: rgb(51 65 85 / 0.4);
	}

	.chevron {
		width: 0.75rem;
		height: 0.75rem;
	}

	.item-content {
		display: flex;
		flex-direction: column;
		gap: var(--spacing-xs, 0.25rem);
		padding: var(--spacing-sm, 0.5rem) var(--spacing-md, 1rem);
	}

	.item-title {
		font-size: 1rem;
		font-weight: 500;
		color: var(--color-surface-950, #030712);
		margin: 0;
		line-height: 1.4;
	}

	:global(.dark) .item-title {
		color: var(--color-surface-50, #f9fafb);
	}

	:global(.dark) .title-link {
		color: var(--color-surface-50, #f9fafb);
	}

	.read-mode-link {
		text-align: left;
		width: 100%;
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
	}

	.read-mode-link:hover .item-title {
		opacity: 0.8;
	}

	.title-link {
		color: inherit;
		text-decoration: none;
	}

	.title-link:hover {
		text-decoration: underline;
	}

	.item-meta {
		display: flex;
		align-items: center;
		gap: var(--spacing-sm, 0.5rem);
	}

	.timestamp {
		font-size: 0.875rem;
		color: var(--color-surface-700, #374151);
	}

	:global(.dark) .timestamp {
		color: var(--color-surface-300, #d1d5db);
	}

	.icon-link {
		padding: 0.125rem;
		color: var(--color-surface-700, #374151);
		transition: opacity 0.15s ease;
	}

	:global(.dark) .icon-link {
		color: var(--color-surface-300, #d1d5db);
	}

	.icon-link:hover {
		opacity: 0.8;
	}
</style>
