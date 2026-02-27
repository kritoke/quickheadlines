import { loadFeeds, loadFeedConfig, feedState } from './feedStore.svelte';
import { loadTimeline, loadTimelineConfig, checkClusteringStatus, timelineState } from './timelineStore.svelte';

export interface EffectConfig {
	refreshInterval?: number;
	pollingInterval?: number;
	clusteringCheckInterval?: number;
}

export interface EffectHandles {
	refreshInterval: ReturnType<typeof setInterval> | null;
	configInterval: ReturnType<typeof setInterval> | null;
	pollTimeout: ReturnType<typeof setTimeout> | null;
	clusteringInterval: ReturnType<typeof setInterval> | null;
}

function createEffectHandles(): EffectHandles {
	return {
		refreshInterval: null,
		configInterval: null,
		pollTimeout: null,
		clusteringInterval: null
	};
}

export function createFeedEffects(config: EffectConfig = {}) {
	const handles = createEffectHandles();
	let lastUpdate = Date.now();
	let saveScrollY = 0;
	
	const refreshMs = (config.refreshInterval ?? 10) * 60 * 1000;
	
	async function pollForUpdates() {
		try {
			const response = await fetch(`/api/events?last_update=${lastUpdate}`);
			const text = await response.text();
			
			const lines = text.split('\n');
			for (const line of lines) {
				if (line.startsWith('event: feed_update')) {
					const dataLine = lines.find(l => l.startsWith('data: '));
					if (dataLine) {
						const timestamp = parseInt(dataLine.replace('data: ', ''));
						if (timestamp > lastUpdate) {
							console.log('[FeedEffects] Update received, reloading...');
							lastUpdate = timestamp;
							saveScrollY = window.scrollY;
							await loadFeeds(feedState.activeTab, true);
							window.scrollTo(0, saveScrollY);
						}
					}
				}
			}
		} catch (e) {
			console.warn('[FeedEffects] Poll failed:', e);
		}
		
		handles.pollTimeout = setTimeout(pollForUpdates, 1000);
	}
	
	async function setupRefresh() {
		const minutes = await loadFeedConfig();
		handles.refreshInterval = setInterval(() => {
			loadFeeds(feedState.activeTab, true);
		}, minutes * 60 * 1000);
		console.log('[FeedEffects] Refresh interval:', minutes, 'minutes');
	}
	
	function start() {
		setupRefresh();
		pollForUpdates();
		
		handles.configInterval = setInterval(() => {
			loadFeedConfig();
		}, 60000);
	}
	
	function stop() {
		if (handles.refreshInterval) clearInterval(handles.refreshInterval);
		if (handles.configInterval) clearInterval(handles.configInterval);
		if (handles.pollTimeout) clearTimeout(handles.pollTimeout);
		if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
	}
	
	return { start, stop, handles };
}

export function createTimelineEffects(config: EffectConfig = {}) {
	const handles = createEffectHandles();
	let lastUpdate = Date.now();
	let saveScrollY = 0;
	
	const refreshMs = (config.refreshInterval ?? 10) * 60 * 1000;
	
	async function pollForUpdates() {
		try {
			const response = await fetch(`/api/events?last_update=${lastUpdate}`);
			const text = await response.text();
			
			const lines = text.split('\n');
			for (const line of lines) {
				if (line.startsWith('event: feed_update')) {
					const dataLine = lines.find(l => l.startsWith('data: '));
					if (dataLine) {
						const timestamp = parseInt(dataLine.replace('data: ', ''));
						if (timestamp > lastUpdate) {
							console.log('[TimelineEffects] Update received, reloading...');
							lastUpdate = timestamp;
							saveScrollY = window.scrollY;
							await loadTimeline();
							window.scrollTo(0, saveScrollY);
						}
					}
				}
			}
		} catch (e) {
			console.warn('[TimelineEffects] Poll failed:', e);
		}
		
		handles.pollTimeout = setTimeout(pollForUpdates, 1000);
	}
	
	async function checkClustering() {
		const isClustering = await checkClusteringStatus();
		
		if (isClustering && !timelineState.isClustering) {
			timelineState.isClustering = true;
			handles.clusteringInterval = setInterval(checkClustering, 5000);
		} else if (!isClustering && timelineState.isClustering) {
			timelineState.isClustering = false;
			if (handles.clusteringInterval) {
				clearInterval(handles.clusteringInterval);
				handles.clusteringInterval = null;
			}
			saveScrollY = window.scrollY;
			await loadTimeline();
			window.scrollTo(0, saveScrollY);
		}
	}
	
	async function setupRefresh() {
		const minutes = await loadTimelineConfig();
		handles.refreshInterval = setInterval(() => {
			loadTimeline();
		}, minutes * 60 * 1000);
		console.log('[TimelineEffects] Refresh interval:', minutes, 'minutes');
	}
	
	function start() {
		loadTimeline();
		setupRefresh();
		pollForUpdates();
		checkClustering();
	}
	
	function stop() {
		if (handles.refreshInterval) clearInterval(handles.refreshInterval);
		if (handles.configInterval) clearInterval(handles.configInterval);
		if (handles.pollTimeout) clearTimeout(handles.pollTimeout);
		if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
	}
	
	return { start, stop, handles };
}

export function createInfiniteScrollObserver(
	sentinel: HTMLDivElement,
	onIntersect: () => void,
	hasMore: boolean,
	isLoading: boolean
) {
	const observer = new IntersectionObserver(
		(entries) => {
			entries.forEach(entry => {
				if (entry.isIntersecting && !isLoading && hasMore) {
					onIntersect();
				}
			});
		},
		{ rootMargin: '500px' }
	);
	
	observer.observe(sentinel);
	
	return () => observer.disconnect();
}
