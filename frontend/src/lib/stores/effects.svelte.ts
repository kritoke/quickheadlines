import { loadFeeds, loadFeedConfig, feedState } from './feedStore.svelte';
import { loadTimeline, loadTimelineConfig, checkClusteringStatus, timelineState } from './timelineStore.svelte';
import { createLiveConnection, type ConnectionState } from '$lib/websocket';
import { fetchConfig } from '$lib/api';
import { setConnectionState } from './connection.svelte';

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
	let liveConnection: ReturnType<typeof createLiveConnection> | null = null;
	let useWebSocket = false;

	async function checkConfig() {
		try {
			const cfg = await fetchConfig();
			useWebSocket = cfg.use_websocket ?? false;
			return cfg.refresh_minutes || 10;
		} catch {
			return 10;
		}
	}

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
		const minutes = await checkConfig();
		handles.refreshInterval = setInterval(() => {
			loadFeeds(feedState.activeTab, true);
		}, minutes * 60 * 1000);
		console.log('[FeedEffects] Refresh interval:', minutes, 'minutes');
	}

	async function startWebSocket() {
		liveConnection = createLiveConnection((timestamp) => {
			if (timestamp > lastUpdate) {
				console.log('[FeedEffects] WebSocket update received, reloading...');
				lastUpdate = timestamp;
				saveScrollY = window.scrollY;
				loadFeeds(feedState.activeTab, true);
				window.scrollTo(0, saveScrollY);
			}
		});

		setConnectionState('connecting');

		Object.defineProperty(window, '__liveConnection', {
			value: liveConnection,
			writable: true,
			configurable: true
		});

		const originalConnect = liveConnection.connect;
		liveConnection.connect = () => {
			setConnectionState('connecting');
			return originalConnect();
		};

		liveConnection.connect();
	}

	async function start() {
		const minutes = await checkConfig();

		if (useWebSocket) {
			await startWebSocket();
		} else {
			pollForUpdates();
		}

		handles.refreshInterval = setInterval(() => {
			loadFeeds(feedState.activeTab, true);
		}, minutes * 60 * 1000);

		handles.configInterval = setInterval(async () => {
			const newMinutes = await checkConfig();
			if (handles.refreshInterval) {
				clearInterval(handles.refreshInterval);
				handles.refreshInterval = setInterval(() => {
					loadFeeds(feedState.activeTab, true);
				}, newMinutes * 60 * 1000);
			}

			if (!useWebSocket) {
				const cfg = await fetchConfig();
				if (cfg.use_websocket && !liveConnection) {
					console.log('[FeedEffects] WebSocket enabled, switching...');
					await startWebSocket();
				}
			}
		}, 60000);
	}

	function stop() {
		if (handles.refreshInterval) clearInterval(handles.refreshInterval);
		if (handles.configInterval) clearInterval(handles.configInterval);
		if (handles.pollTimeout) clearTimeout(handles.pollTimeout);
		if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
		if (liveConnection) liveConnection.disconnect();
	}

	return { start, stop, handles, getLiveConnection: () => liveConnection };
}

export function createTimelineEffects(config: EffectConfig = {}) {
	const handles = createEffectHandles();
	let lastUpdate = Date.now();
	let saveScrollY = 0;
	let liveConnection: ReturnType<typeof createLiveConnection> | null = null;
	let useWebSocket = false;

	async function checkConfig() {
		try {
			const cfg = await fetchConfig();
			useWebSocket = cfg.use_websocket ?? false;
			return cfg.refresh_minutes || 10;
		} catch {
			return 10;
		}
	}

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
		const minutes = await checkConfig();
		handles.refreshInterval = setInterval(() => {
			loadTimeline();
		}, minutes * 60 * 1000);
		console.log('[TimelineEffects] Refresh interval:', minutes, 'minutes');
	}

  async function startWebSocket() {
    liveConnection = createLiveConnection((timestamp) => {
      if (timestamp > lastUpdate) {
        console.log('[TimelineEffects] WebSocket update received, reloading...');
        lastUpdate = timestamp;
        saveScrollY = window.scrollY;
        loadTimeline();
        window.scrollTo(0, saveScrollY);
      }
    });

    setConnectionState('connecting');

    Object.defineProperty(window, '__liveConnection', {
      value: liveConnection,
      writable: true,
      configurable: true
    });

    const originalConnect = liveConnection.connect;
    liveConnection.connect = () => {
      setConnectionState('connecting');
      return originalConnect();
    };

    liveConnection.connect();
  }

	async function start() {
		loadTimeline();

		const minutes = await checkConfig();

		if (useWebSocket) {
			await startWebSocket();
		} else {
			pollForUpdates();
		}

		handles.refreshInterval = setInterval(() => {
			loadTimeline();
		}, minutes * 60 * 1000);

		checkClustering();

		handles.configInterval = setInterval(async () => {
			const newMinutes = await checkConfig();
			if (handles.refreshInterval) {
				clearInterval(handles.refreshInterval);
				handles.refreshInterval = setInterval(() => {
					loadTimeline();
				}, newMinutes * 60 * 1000);
			}

			if (!useWebSocket) {
				const cfg = await fetchConfig();
				if (cfg.use_websocket && !liveConnection) {
					console.log('[TimelineEffects] WebSocket enabled, switching...');
					await startWebSocket();
				}
			}
		}, 60000);
	}

	function stop() {
		if (handles.refreshInterval) clearInterval(handles.refreshInterval);
		if (handles.configInterval) clearInterval(handles.configInterval);
		if (handles.pollTimeout) clearTimeout(handles.pollTimeout);
		if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
		if (liveConnection) liveConnection.disconnect();
	}

	return { start, stop, handles, getLiveConnection: () => liveConnection };
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
