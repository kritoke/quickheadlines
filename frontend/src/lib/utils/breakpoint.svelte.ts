export const breakpointState = $state({ isMobile: false });

let initialized = false;
let resizeHandler: (() => void) | null = null;

export function initBreakpoints() {
	if (initialized || typeof window === 'undefined') return;
	initialized = true;

	const check = () => {
		breakpointState.isMobile = window.innerWidth < 768;
	};

	check();
	resizeHandler = check;
	window.addEventListener('resize', check);
}

export function destroyBreakpoints() {
	if (resizeHandler) {
		window.removeEventListener('resize', resizeHandler);
		resizeHandler = null;
	}
	initialized = false;
}
