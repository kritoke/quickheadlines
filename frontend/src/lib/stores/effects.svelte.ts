import { loadFeeds, feedState } from './feedStore.svelte';
import { loadTimeline, timelineState } from './timelineStore.svelte';
import { websocketConnection } from '$lib/websocket';
import { fetchConfig } from '$lib/api';
import { logger } from '$lib/utils/debug';
import type { WebSocketMessage } from '$lib/websocket';

export interface EffectHandles {
	refreshInterval: ReturnType<typeof setInterval> | null;
	configInterval: ReturnType<typeof setInterval> | null;
	clusteringInterval: ReturnType<typeof setInterval> | null;
}

function createEffectHandles(): EffectHandles {
	return {
		refreshInterval: null,
		configInterval: null,
		clusteringInterval: null
	};
}

let lastUpdate = 0;
let preservedScrollY = 0;
let feedUpdateDebounce: ReturnType<typeof setTimeout> | null = null;
const FEED_UPDATE_DEBOUNCE_MS = 2000;
const CONFIG_CHECK_INTERVAL_MS = 60000;

function resetLastUpdate() {
	lastUpdate = 0;
	logger.log('[Effects] lastUpdate reset');
}

function handleFeedUpdate(timestamp: number) {
	const delta = timestamp - lastUpdate;
	logger.log(`[Effects] Feed update received: ts=${timestamp}, lastUpdate=${lastUpdate}, delta=${delta}ms`);

	if (timestamp >= lastUpdate) {
		logger.log('[Effects] Update accepted, scheduling reload...');
		lastUpdate = timestamp;
		preservedScrollY = window.scrollY;

		if (feedUpdateDebounce) clearTimeout(feedUpdateDebounce);
		feedUpdateDebounce = setTimeout(() => {
			feedUpdateDebounce = null;
			logger.log('[Effects] Debounce fired, reloading feeds and timeline...');
			loadFeeds(feedState.activeTab, true);
			loadTimeline();
			window.scrollTo(0, preservedScrollY);
		}, FEED_UPDATE_DEBOUNCE_MS);
	} else {
		logger.log('[Effects] Update rejected (stale)');
	}
}

function clearDebounce() {
	if (feedUpdateDebounce) {
		clearTimeout(feedUpdateDebounce);
		feedUpdateDebounce = null;
	}
}

function handleClusteringStatus(isClustering: boolean) {
	if (isClustering && !timelineState.isClustering) {
		timelineState.isClustering = true;
	} else if (!isClustering && timelineState.isClustering) {
		timelineState.isClustering = false;
		preservedScrollY = window.scrollY;
		loadTimeline();
		loadFeeds(feedState.activeTab, true);
		window.scrollTo(0, preservedScrollY);
	}
}

function handleWebSocketMessage(message: WebSocketMessage) {
	if (message.type === 'feed_update') {
		handleFeedUpdate(message.timestamp);
	} else if (message.type === 'clustering_status') {
		handleClusteringStatus(message.is_clustering ?? false);
	}
}

async function checkConfig() {
	try {
		const cfg = await fetchConfig();
		return cfg.refresh_minutes || 10;
	} catch {
		return 10;
	}
}

function stopEffects(handles: EffectHandles) {
	if (handles.refreshInterval) clearInterval(handles.refreshInterval);
	if (handles.configInterval) clearInterval(handles.configInterval);
	if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
	clearDebounce();
}

function createRefreshEffect(refreshFn: () => void, onConnect?: () => void): { start: () => void; stop: () => void; handles: EffectHandles } {
	const handles = createEffectHandles();
	let started = false;

	async function start() {
		if (started) return;
		started = true;

		resetLastUpdate();
		websocketConnection.addEventListener(handleWebSocketMessage);
		websocketConnection.connect();

		onConnect?.();

		const minutes = await checkConfig();

		handles.refreshInterval = setInterval(refreshFn, minutes * 60 * 1000);

		handles.configInterval = setInterval(async () => {
			const newMinutes = await checkConfig();
			if (handles.refreshInterval) {
				clearInterval(handles.refreshInterval);
				handles.refreshInterval = setInterval(refreshFn, newMinutes * 60 * 1000);
			}
		}, CONFIG_CHECK_INTERVAL_MS);
	}

	function stop() {
		if (!started) return;
		started = false;
		stopEffects(handles);
		websocketConnection.removeEventListener(handleWebSocketMessage);
	}

	return { start, stop, handles };
}

export function createFeedEffects(): { start: () => void; stop: () => void; handles: EffectHandles } {
	return createRefreshEffect(() => loadFeeds(feedState.activeTab, true));
}

export function createTimelineEffects(): { start: () => void; stop: () => void; handles: EffectHandles } {
	return createRefreshEffect(loadTimeline);
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