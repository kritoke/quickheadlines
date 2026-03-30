export const breakpointState = $state({ isMobile: false });

let initialized = false;

export function initBreakpoints() {
	if (initialized || typeof window === 'undefined') return;
	initialized = true;

	const check = () => {
		breakpointState.isMobile = window.innerWidth < 768;
	};

	check();
	window.addEventListener('resize', check);
}
