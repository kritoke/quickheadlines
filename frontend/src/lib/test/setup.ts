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
		playState: 'idle'
	};
};

Object.defineProperty(global.Element.prototype, 'animate', {
	writable: true,
	value: global.Element.prototype.animate
});
