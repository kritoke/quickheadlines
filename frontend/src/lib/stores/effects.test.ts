import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const listeners = new Set<(m: any) => void>();
vi.mock('#lib/websocket', () => ({
	websocketConnection: {
		addEventListener: (l: any) => listeners.add(l),
		removeEventListener: (l: any) => listeners.delete(l),
		connect: vi.fn(),
	},
}));

let resolveConfig: ((n: number) => void) | null = null;
const pendingConfig = () => new Promise<number>((r) => { resolveConfig = r; });
vi.mock('./feedStore.svelte', () => ({ loadFeeds: vi.fn(async () => {}), feedState: { activeTab: 'all' }, loadFeedConfig: vi.fn(() => pendingConfig()) }));
vi.mock('./timelineStore.svelte', () => ({ loadTimeline: vi.fn(async () => {}), timelineState: { isClustering: false }, loadTimelineConfig: vi.fn(() => pendingConfig()) }));

import { createFeedEffects, createTimelineEffects } from './effects.svelte';
import { loadFeeds } from './feedStore.svelte';
import { loadTimeline } from './timelineStore.svelte';

describe('refresh effects lifecycle', () => {
	beforeEach(() => { listeners.clear(); vi.useFakeTimers(); });
	afterEach(() => vi.useRealTimers());

	it('creates no intervals when stopped before start() finishes', async () => {
		const setIntervalSpy = vi.spyOn(globalThis, 'setInterval');
		const fx = createFeedEffects();
		const starting = fx.start();
		fx.stop();                 // page left while config was loading
		resolveConfig!(10);
		await starting;
		expect(setIntervalSpy).not.toHaveBeenCalled();
		expect(listeners.size).toBe(0);
		setIntervalSpy.mockRestore();
	});

	it("one instance's stop() does not unsubscribe the other", async () => {
		const feed = createFeedEffects();
		const timeline = createTimelineEffects();
		const a = feed.start(); resolveConfig!(10); await a;
		const b = timeline.start(); resolveConfig!(10); await b;
		expect(listeners.size).toBe(2);
		feed.stop();
		expect(listeners.size).toBe(1);
		timeline.stop();
		expect(listeners.size).toBe(0);
	});

	it('a feed_update reloads only the owning page', async () => {
		const timeline = createTimelineEffects();
		const t = timeline.start(); resolveConfig!(10); await t;
		vi.mocked(loadFeeds).mockClear();
		vi.mocked(loadTimeline).mockClear();
		listeners.forEach((l) => l({ type: 'feed_update', timestamp: Date.now() }));
		await vi.advanceTimersByTimeAsync(2500);
		expect(loadTimeline).toHaveBeenCalledTimes(1);
		expect(loadFeeds).not.toHaveBeenCalled();
		timeline.stop();
	});
});
