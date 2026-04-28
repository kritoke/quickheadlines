<script lang="ts">
	import AppHeader from '$lib/components/AppHeader.svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import DOMPurify from 'dompurify';
	
	let content: string | null = $state(null);
	let title: string = $state('');
	let loading = $state(true);
	let error: string | null = $state(null);
	let articleUrl: string | null = $state(null);
	let isSummary = $state(false);
	let commentsUrl: string | null = $state(null);
	
	const SUMMARY_LENGTH_THRESHOLD = 500;
	const SUMMARY_PARAGRAPH_COUNT = 2;
	
	onMount(() => {
		const url = $page.url.searchParams.get('url');
		const pageTitle = $page.url.searchParams.get('title');
		
		if (url) {
			articleUrl = decodeURIComponent(url);
			title = pageTitle ? decodeURIComponent(pageTitle) : 'Article';
			fetchContent();
		} else {
			error = 'No article URL provided';
			loading = false;
		}
	});
	
	async function fetchContent() {
		loading = true;
		error = null;
		
		try {
			const response = await fetch(`/api/content?link=${encodeURIComponent(articleUrl!)}`);
			const data = await response.json();
			
			if (data.error) {
				error = data.error;
			} else if (data.content) {
				const cleaned = cleanContent(data.content, articleUrl!);
				const sanitized = DOMPurify.sanitize(cleaned, { USE_PROFILES: { html: true } });
				content = sanitized;
				isSummary = detectSummary(sanitized);
			} else {
				error = 'No content available for this article';
			}
		} catch (e) {
			error = 'Failed to load content';
		} finally {
			loading = false;
		}
	}
	
	function cleanContent(htmlContent: string, articleUrl: string): string {
		const parser = new DOMParser();
		const doc = parser.parseFromString(htmlContent, 'text/html');
		
		const articleBase = articleUrl.replace(/^https?:\/\//, '').replace(/\/$/, '');
		const decodedUrl = decodeURIComponent(articleUrl);
		const decodedBase = decodedUrl.replace(/^https?:\/\//, '').replace(/\/$/, '');
		
		const selfLinkTexts = [
			'read more', 'read full', 'continue reading', 'continue', 'more', 'more here',
			'click here', 'click', 'learn more', 'learn', 'full article', 'full story',
			'view article', 'view', 'view full', 'read story', 'read',
			'»', '→', '...', '…', '›'
		];
		
		const commentsTexts = ['comment', 'comments', 'discuss', 'discussion', 'reply', 'replies'];
		
		doc.querySelectorAll('a[href]').forEach(link => {
			const rawHref = link.getAttribute('href') || '';
			let href = rawHref.replace(/^https?:\/\//, '').replace(/\/$/, '').split('#')[0].split('?')[0];
			const linkBase = href;
			const hash = rawHref.includes('#') ? rawHref.split('#')[1] : '';
			
			const isSelfLink = linkBase === articleBase || 
			                   linkBase === decodedBase ||
			                   linkBase === articleBase.split('/').slice(-2).join('/') ||
			                   linkBase === decodedBase.split('/').slice(-2).join('/') ||
			                   href === articleUrl || 
			                   href === decodedUrl ||
			                   href.endsWith(articleBase.split('/').slice(-1)[0]) ||
			                   href.endsWith(decodedBase.split('/').slice(-1)[0]);
			
			if (isSelfLink) {
				const text = link.textContent?.trim().toLowerCase() || '';
				const isCtaLink = selfLinkTexts.some(cta => text === cta || text.includes(cta) || cta.includes(text));
				const isCommentsLink = commentsTexts.some(cta => text === cta || text.includes(cta));
				
				if (isCommentsLink && rawHref) {
					commentsUrl = rawHref;
					const parent = link.parentElement;
					if (parent && parent.textContent?.trim() === link.textContent?.trim()) {
						parent.remove();
					} else {
						link.remove();
					}
					return;
				}
				
				if (isCtaLink || href === articleUrl || href === decodedUrl) {
					const parent = link.parentElement;
					if (parent && parent.textContent?.trim() === link.textContent?.trim()) {
						parent.replaceWith(document.createTextNode(parent.textContent));
					} else {
						link.replaceWith(document.createTextNode(link.textContent || ''));
					}
				}
			}
		});
		
		return doc.body.innerHTML;
	}
	
	function detectSummary(htmlContent: string): boolean {
		const textOnly = htmlContent.replace(/<[^>]*>/g, '').trim();
		if (textOnly.length < SUMMARY_LENGTH_THRESHOLD) return true;
		const paragraphCount = (htmlContent.match(/<p/g) || []).length;
		if (paragraphCount < SUMMARY_PARAGRAPH_COUNT) return true;
		if (textOnly.endsWith('...') || textOnly.endsWith('…')) return true;
		return false;
	}
	
	function handleBack() {
		goto('/');
	}
	
	function openOriginal() {
		if (articleUrl) {
			window.open(articleUrl, '_blank', 'noopener,noreferrer');
		}
	}
</script>

<svelte:head>
	<title>{title} - Reader</title>
</svelte:head>

<AppHeader
	title="Reader"
	viewLink={{ href: '/', icon: 'rss' }}
	searchExpanded={false}
	onSearchToggle={() => {}}
>
	<button
		onclick={handleBack}
		class="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
		title="Back to feeds"
	>
		<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
			<path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
		</svg>
	</button>
	
	{#if articleUrl}
		<button
			onclick={openOriginal}
			class="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
			title="Open original article"
		>
			<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 theme-text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
				<path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
			</svg>
		</button>
	{/if}
</AppHeader>

<main class="pt-16 px-4 md:px-6 max-w-[1400px] mx-auto">
	{#if loading}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 border-4 theme-accent-border border-t-transparent rounded-full animate-spin"></div>
			<span class="ml-4 theme-text-secondary">Loading article...</span>
		</div>
	{:else if error}
		<div class="text-center py-20">
			<svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto theme-text-tertiary mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
				<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
			</svg>
			<p class="theme-text-secondary mb-4">{error}</p>
			<button
				onclick={handleBack}
				class="px-4 py-2 rounded-lg theme-bg-secondary theme-text-primary theme-border"
			>
				Back to feeds
			</button>
		</div>
	{:else if content}
		<article class="py-6 max-w-4xl mx-auto">
			<h1 class="text-2xl sm:text-3xl font-bold theme-text-primary mb-6">{title}</h1>
			
			{#if isSummary}
				<div class="mb-4 px-3 py-2 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50">
					<p class="text-sm text-amber-800 dark:text-amber-200 flex items-center gap-2">
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
						<span><strong>Summary only</strong> — Full article may contain more content</span>
					</p>
				</div>
			{/if}
			
			<div class="prose prose-slate dark:prose-invert max-w-none
				prose-a:text-[var(--theme-accent)] prose-a:no-underline hover:prose-a:underline
				prose-a:font-medium prose-headings:theme-text-primary
				prose-img:rounded-lg prose-pre:bg-slate-100 prose-pre:dark:bg-slate-800
				prose-blockquote:border-l-[var(--theme-accent)]">
				{@html content}
			</div>
			
			<div class="mt-8 pt-6 border-t border-slate-200 dark:border-slate-700 flex flex-wrap gap-3">
				<a
					href={articleUrl}
					target="_blank"
					rel="noopener noreferrer"
					class="inline-flex items-center gap-2 px-4 py-2 rounded-lg theme-bg-secondary theme-text-primary theme-border hover:opacity-80 transition-opacity text-sm font-medium"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
					</svg>
					View original article
				</a>
				{#if commentsUrl}
					<a
						href={commentsUrl}
						target="_blank"
						rel="noopener noreferrer"
						class="inline-flex items-center gap-2 px-4 py-2 rounded-lg theme-bg-secondary theme-text-primary theme-border hover:opacity-80 transition-opacity text-sm font-medium"
					>
						<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
						</svg>
						View comments
					</a>
				{/if}
			</div>
		</article>
	{/if}
</main>