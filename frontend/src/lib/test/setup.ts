import '@testing-library/jest-dom';

global.ResizeObserver = class ResizeObserver {
	observe() {}
	unobserve() {}
	disconnect() {}
};

global.Element.prototype.animate = function() {
	return {
		play: () => {},
		pause: () => {},
		cancel: () => {},
		finish: () => {},
		onfinish: null,
		playState: 'idle' as const,
		currentTime: 0,
		effect: null,
		finished: Promise.resolve(),
		id: '',
		pending: false,
		progress: null,
		ready: Promise.resolve(),
		reverse: () => {},
		startTime: 0,
		updatePlaybackRate: () => {},
		composite: 'replace' as const,
		fill: 'none' as const,
		iterationComposite: 'replace' as const,
		oncancel: null,
		onremove: null,
		pseudoElement: null,
		replaceState: 'active' as const,
		playbackRate: 1,
		timeline: null,
		commitStyles: () => {},
		persist: () => {},
		cancelAll: () => {},
		finishAll: () => {},
		getAnimations: () => []
	} as unknown as Animation;
};

Object.defineProperty(global.Element.prototype, 'animate', {
	writable: true,
	value: global.Element.prototype.animate
});
