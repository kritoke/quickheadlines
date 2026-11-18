import { describe, it, expect, vi, beforeEach } from 'vitest';

type Deferred<T> = { promise: Promise<T>; resolve: (v: T) => void; reject: (e: unknown) => void };
function deferred<T>(): Deferred<T> {
	let resolve!: (v: T) => void, reject!: (e: unknown) => void;
	const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
	return { promise, resolve, reject };
}

const pending: Deferred<any>[] = [];
vi.mock('#lib/api', () => ({
	fetchTimeline: vi.fn(() => { const d = deferred<any>(); pending.push(d); return d.promise; }),
	fetchConfig: vi.fn(async () => ({ refresh_minutes: 10 })),
	RateLimitError: class RateLimitError extends Error { retryAfterMs = 1000; },
}));

const item = (id: string) => ({ id, title: `t${id}`, feed_title: 'f' }) as any;
const page = (ids: string[], has_more = true) => ({ items: ids.map(item), has_more });

const flush = () => new Promise((r) => setTimeout(r, 0));

describe('timelineStore request tracking', () => {
	let store: typeof import('./timelineStore.svelte');

	beforeEach(async () => {
		pending.length = 0;
		vi.resetModules();
		store = await import('./timelineStore.svelte');
		store.resetTimelineStore();
	});

	async function loadInitial(ids = ['1', '2']) {
		const p = store.loadTimeline(false, 'all');
		pending.shift()!.resolve(page(ids));
		await p;
	}

	it('does not start a second append while one is in flight', async () => {
		await loadInitial();
		store.handleLoadMore();
		expect(store.timelineState.loadingMore).toBe(true);
		const skipped = await store.handleLoadMore();
		expect(skipped).toBe(false);
		expect(pending.length).toBe(1);
		pending.shift()!.resolve(page(['3']));
		await flush();
		expect(store.timelineState.loadingMore).toBe(false);
		expect(store.timelineState.items.map((i) => i.id)).toEqual(['1', '2', '3']);
	});

	it('discards an append that started before a refresh replaced the list', async () => {
		await loadInitial();
		store.handleLoadMore();               // append in flight (old generation)
		const append = pending.shift()!;
		const refresh = store.loadTimeline(false, 'other-tab'); // tab change supersedes
		const refreshReq = pending.shift()!;
		refreshReq.resolve(page(['a', 'b']));
		await refresh;
		append.resolve(page(['stale']));
		await flush();
		expect(store.timelineState.items.map((i) => i.id)).toEqual(['a', 'b']);
		expect(store.timelineState.status).toBe('idle');
		expect(store.timelineState.loadingMore).toBe(false);
	});

	it('loadAllRemainingItems terminates when a load is already in flight', async () => {
		await loadInitial();
		store.loadTimeline(false, 'all'); // refresh in flight → appends are skipped
		await Promise.race([
			store.loadAllRemainingItems(),
			new Promise((_, rej) => setTimeout(() => rej(new Error('spun forever')), 500)),
		]);
	});

	it('loadAllRemainingItems stops after a failed page', async () => {
		await loadInitial();
		const all = store.loadAllRemainingItems();
		await flush();
		pending.shift()!.reject(new Error('network'));
		await all;
		expect(store.timelineState.status).toBe('error');
	});
});
