import { loadFeeds, feedState } from "./feedStore.svelte";
import { loadTimeline, timelineState } from "./timelineStore.svelte";
import { websocketConnection } from "#lib/websocket";
import { logger } from "#lib/utils/debug";
import type { WebSocketMessage } from "#lib/websocket";
import { loadConfigForStore } from "#lib/utils/storeConfig";
import { setRefreshMinutes as setFeedRefreshMinutes } from "./feedStore.svelte";
import { setRefreshMinutes as setTimelineRefreshMinutes } from "./timelineStore.svelte";

export interface EffectHandles {
	refreshInterval: ReturnType<typeof setInterval> | null;
	configInterval: ReturnType<typeof setInterval> | null;
	clusteringInterval: ReturnType<typeof setInterval> | null;
}

function createEffectHandles(): EffectHandles {
	return {
		refreshInterval: null,
		configInterval: null,
		clusteringInterval: null,
	};
}

const FEED_UPDATE_DEBOUNCE_MS = 2000;
const CONFIG_CHECK_INTERVAL_MS = 60000;

/** Per-effect-instance state, so two pages' effects never clobber each other. */
interface EffectContext {
	lastUpdate: number;
	feedUpdateDebounce: ReturnType<typeof setTimeout> | null;
}

/** Pure predicate: should this update be accepted? */
function shouldAcceptUpdate(timestamp: number, lastUpdate: number): boolean {
	return timestamp >= lastUpdate;
}

/** Reload feeds + timeline, restoring scroll only after the data has landed. */
async function reloadPreservingScroll(): Promise<void> {
	const scrollY = window.scrollY;
	await Promise.all([loadFeeds(feedState.activeTab, true), loadTimeline()]);
	window.scrollTo(0, scrollY);
}

function handleFeedUpdate(ctx: EffectContext, timestamp: number) {
	const delta = timestamp - ctx.lastUpdate;
	logger.log(
		`[Effects] Feed update received: ts=${timestamp}, lastUpdate=${ctx.lastUpdate}, delta=${delta}ms`,
	);

	if (shouldAcceptUpdate(timestamp, ctx.lastUpdate)) {
		logger.log("[Effects] Update accepted, scheduling reload...");
		ctx.lastUpdate = timestamp;

		if (ctx.feedUpdateDebounce) clearTimeout(ctx.feedUpdateDebounce);
		ctx.feedUpdateDebounce = setTimeout(() => {
			ctx.feedUpdateDebounce = null;
			logger.log("[Effects] Debounce fired, reloading feeds and timeline...");
			void reloadPreservingScroll();
		}, FEED_UPDATE_DEBOUNCE_MS);
	} else {
		logger.log("[Effects] Update rejected (stale)");
	}
}

/** Pure predicate: has clustering state actually changed? */
function clusteringChanged(
	wasClustering: boolean,
	isClustering: boolean,
): boolean {
	return wasClustering !== isClustering;
}

function handleClusteringStatus(isClustering: boolean) {
	if (!clusteringChanged(timelineState.isClustering, isClustering)) return;

	timelineState.isClustering = isClustering;
	if (!isClustering) {
		void reloadPreservingScroll();
	}
}

async function checkConfig(): Promise<number> {
	return loadConfigForStore(feedState, setFeedRefreshMinutes);
}

function stopEffects(handles: EffectHandles, ctx: EffectContext) {
	if (handles.refreshInterval) clearInterval(handles.refreshInterval);
	if (handles.configInterval) clearInterval(handles.configInterval);
	if (handles.clusteringInterval) clearInterval(handles.clusteringInterval);
	handles.refreshInterval = null;
	handles.configInterval = null;
	handles.clusteringInterval = null;
	if (ctx.feedUpdateDebounce) {
		clearTimeout(ctx.feedUpdateDebounce);
		ctx.feedUpdateDebounce = null;
	}
}

function createRefreshEffect(
	refreshFn: () => void,
	onConnect?: () => void,
): { start: () => Promise<void>; stop: () => void; handles: EffectHandles } {
	const handles = createEffectHandles();
	const ctx: EffectContext = { lastUpdate: 0, feedUpdateDebounce: null };
	let started = false;

	// A distinct function per instance: the connection stores listeners in a
	// Set, so sharing one module-level function would let one page's stop()
	// unsubscribe the other page.
	const listener = (message: WebSocketMessage) => {
		if (message.type === "feed_update") {
			handleFeedUpdate(ctx, message.timestamp);
		} else if (message.type === "clustering_status") {
			handleClusteringStatus(message.is_clustering ?? false);
		}
	};

	async function start() {
		if (started) return;
		started = true;

		ctx.lastUpdate = 0;
		websocketConnection.addEventListener(listener);
		websocketConnection.connect();

		onConnect?.();

		const minutes = await checkConfig();
		// stop() may have run while we awaited; don't create orphaned intervals.
		if (!started) return;

		handles.refreshInterval = setInterval(refreshFn, minutes * 60 * 1000);

		handles.configInterval = setInterval(async () => {
			const newMinutes = await checkConfig();
			if (!started) return;
			if (handles.refreshInterval) {
				clearInterval(handles.refreshInterval);
				handles.refreshInterval = setInterval(
					refreshFn,
					newMinutes * 60 * 1000,
				);
			}
		}, CONFIG_CHECK_INTERVAL_MS);
	}

	function stop() {
		if (!started) return;
		started = false;
		stopEffects(handles, ctx);
		websocketConnection.removeEventListener(listener);
	}

	return { start, stop, handles };
}

export function createFeedEffects(): {
	start: () => Promise<void>;
	stop: () => void;
	handles: EffectHandles;
} {
	return createRefreshEffect(() => loadFeeds(feedState.activeTab, true));
}

export function createTimelineEffects(): {
	start: () => Promise<void>;
	stop: () => void;
	handles: EffectHandles;
} {
	return createRefreshEffect(loadTimeline);
}

export function createInfiniteScrollObserver(
	sentinel: HTMLDivElement,
	onIntersect: () => void,
	hasMore: boolean,
	isLoading: boolean,
) {
	const observer = new IntersectionObserver(
		(entries) => {
			entries.forEach((entry) => {
				if (entry.isIntersecting && !isLoading && hasMore) {
					onIntersect();
				}
			});
		},
		{ rootMargin: "500px" },
	);

	observer.observe(sentinel);

	return () => observer.disconnect();
}
