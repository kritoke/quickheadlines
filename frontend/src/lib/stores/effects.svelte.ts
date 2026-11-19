import { loadFeeds, getLoadedTab, loadFeedConfig } from "./feedStore.svelte";
import { loadTimeline, timelineState, loadTimelineConfig } from "./timelineStore.svelte";
import { websocketConnection } from "#lib/websocket";
import type { WebSocketMessage } from "#lib/websocket";
import { logger } from "#lib/utils/debug";

const FEED_UPDATE_DEBOUNCE_MS = 2000;
const CONFIG_CHECK_INTERVAL_MS = 60000;

export interface RefreshEffect {
	start: () => Promise<void>;
	stop: () => void;
}

/**
 * One instance per page. It owns that page's refresh interval, config poll and
 * websocket listener, and only ever reloads that page's own data.
 */
function createRefreshEffect(
	refresh: () => Promise<void>,
	loadConfig: () => Promise<number>,
): RefreshEffect {
	let started = false;
	let lastUpdate = 0;
	let refreshInterval: ReturnType<typeof setInterval> | null = null;
	let configInterval: ReturnType<typeof setInterval> | null = null;
	let debounce: ReturnType<typeof setTimeout> | null = null;
	let refreshMinutes = 0;

	async function reloadPreservingScroll(): Promise<void> {
		const scrollY = window.scrollY;
		await refresh();
		window.scrollTo(0, scrollY);
	}

	// A distinct function per instance: the connection stores listeners in a
	// Set, so sharing one function would let one page's stop() unsubscribe another.
	const listener = (message: WebSocketMessage) => {
		if (message.type === "feed_update") {
			if (message.timestamp < lastUpdate) return; // stale
			lastUpdate = message.timestamp;
			if (debounce) clearTimeout(debounce);
			debounce = setTimeout(() => {
				debounce = null;
				void reloadPreservingScroll();
			}, FEED_UPDATE_DEBOUNCE_MS);
		} else if (message.type === "clustering_status") {
			const isClustering = message.is_clustering ?? false;
			if (timelineState.isClustering === isClustering) return;
			timelineState.isClustering = isClustering;
			if (!isClustering) void reloadPreservingScroll();
		}
	};

	function setRefreshInterval(minutes: number) {
		if (minutes === refreshMinutes && refreshInterval) return;
		refreshMinutes = minutes;
		if (refreshInterval) clearInterval(refreshInterval);
		refreshInterval = setInterval(() => void refresh(), minutes * 60 * 1000);
	}

	async function start() {
		if (started) return;
		started = true;
		lastUpdate = 0;
		websocketConnection.addEventListener(listener);
		websocketConnection.connect();

		const minutes = await loadConfig();
		// stop() may have run while we awaited; don't create orphaned intervals.
		if (!started) return;
		setRefreshInterval(minutes);

		configInterval = setInterval(async () => {
			const next = await loadConfig();
			if (started) setRefreshInterval(next);
		}, CONFIG_CHECK_INTERVAL_MS);
	}

	function stop() {
		if (!started) return;
		started = false;
		if (refreshInterval) clearInterval(refreshInterval);
		if (configInterval) clearInterval(configInterval);
		if (debounce) clearTimeout(debounce);
		refreshInterval = configInterval = debounce = null;
		refreshMinutes = 0;
		websocketConnection.removeEventListener(listener);
		logger.log("[Effects] stopped");
	}

	return { start, stop };
}

export function createFeedEffects(): RefreshEffect {
	return createRefreshEffect(() => loadFeeds(getLoadedTab(), true), loadFeedConfig);
}

export function createTimelineEffects(): RefreshEffect {
	return createRefreshEffect(() => loadTimeline(), loadTimelineConfig);
}
