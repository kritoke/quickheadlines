import { loadFeeds, feedState } from './feedStore.svelte';
import { loadTimeline, timelineState } from './timelineStore.svelte';
import { websocketConnection, onReconnect } from '$lib/websocket';
import { fetchConfig } from '$lib/api';
import { logger } from '$lib/utils/debug';

export interface EffectConfig {
	refreshInterval?: number;
	clusteringCheckInterval?: number;
}

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

// Shared WebSocket event handler for feed updates
let lastUpdate = Date.now();
let saveScrollY = 0;
let feedUpdateDebounce: ReturnType<typeof setTimeout> | null = null;
const FEED_UPDATE_DEBOUNCE_MS = 2000;

function handleFeedUpdate(timestamp: number) {
	if (timestamp > lastUpdate) {
		logger.log('[Effects] Feed update received, scheduling reload...');
		lastUpdate = timestamp;
		saveScrollY = window.scrollY;

		if (feedUpdateDebounce) clearTimeout(feedUpdateDebounce);
		feedUpdateDebounce = setTimeout(() => {
			feedUpdateDebounce = null;
			loadFeeds(feedState.activeTab, true);
			loadTimeline();
			window.scrollTo(0, saveScrollY);
		}, FEED_UPDATE_DEBOUNCE_MS);
	}
}

// Handle clustering status updates from WebSocket
function handleClusteringStatus(isClustering: boolean) {
	if (isClustering && !timelineState.isClustering) {
		timelineState.isClustering = true;
	} else if (!isClustering && timelineState.isClustering) {
		timelineState.isClustering = false;
		saveScrollY = window.scrollY;
		loadTimeline();
		loadFeeds(feedState.activeTab, true);
		window.scrollTo(0, saveScrollY);
	}
}

// WebSocket message handler
function handleWebSocketMessage(message: any) {
	if (message.type === 'feed_update') {
		handleFeedUpdate(message.timestamp);
	} else if (message.type === 'clustering_status') {
		handleClusteringStatus(message.is_clustering);
	}
}

// Set up reconnect hook to refresh data after connection is restored
onReconnect(() => {
	logger.log('[Effects] Reconnected, refreshing data...');
	saveScrollY = window.scrollY;
	loadFeeds(feedState.activeTab, true);
	loadTimeline();
	window.scrollTo(0, saveScrollY);
});

async function checkConfig() {
	try {
		const cfg = await fetchConfig();
		return cfg.refresh_minutes || 10;
	} catch {
		return 10;
	}
}

export function createFeedEffects(_config: EffectConfig = {}) {
	const handles = createEffectHandles();

	async function start() {
		// Connect to shared WebSocket
		websocketConnection.addEventListener(handleWebSocketMessage);
		websocketConnection.connect();

		const minutes = await checkConfig();

		// Keep refresh interval for periodic data loading
		handles.refreshInterval = setInterval(() => {
			loadFeeds(feedState.activeTab, true);
		}, minutes * 60 * 1000);

		// Keep config interval to update refresh rate
		handles.configInterval = setInterval(async () => {
			const newMinutes = await checkConfig();
			if (handles.refreshInterval) {
				clearInterval(handles.refreshInterval);
				handles.refreshInterval = setInterval(() => {
					loadFeeds(feedState.activeTab, true);
				}, newMinutes * 60 * 1000);
			}
		}, 60000);
	}

	function stop() {
		if (handles.refreshInterval) clearInterval(handles.refreshInterval);
		if (handles.configInterval) clearInterval(handles.configInterval);
		if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
		websocketConnection.removeEventListener(handleWebSocketMessage);
	}

	return { start, stop, handles };
}

export function createTimelineEffects(_config: EffectConfig = {}) {
	const handles = createEffectHandles();

	async function start() {
		// Connect to shared WebSocket
		websocketConnection.addEventListener(handleWebSocketMessage);
		websocketConnection.connect();

		// Initial load
		loadTimeline();

		const minutes = await checkConfig();

		// Keep refresh interval for periodic data loading
		handles.refreshInterval = setInterval(() => {
			loadTimeline();
		}, minutes * 60 * 1000);

		// Keep config interval
		handles.configInterval = setInterval(async () => {
			const newMinutes = await checkConfig();
			if (handles.refreshInterval) {
				clearInterval(handles.refreshInterval);
				handles.refreshInterval = setInterval(() => {
					loadTimeline();
				}, newMinutes * 60 * 1000);
			}
		}, 60000);
	}

	function stop() {
		if (handles.refreshInterval) clearInterval(handles.refreshInterval);
		if (handles.configInterval) clearInterval(handles.configInterval);
		if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
		websocketConnection.removeEventListener(handleWebSocketMessage);
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