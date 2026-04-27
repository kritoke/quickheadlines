export const readModeState = $state({
	mode: 'link' as 'link' | 'read',
	mounted: false
});

export function toggleReadMode(): void {
	readModeState.mode = readModeState.mode === 'link' ? 'read' : 'link';
	if (typeof localStorage !== 'undefined') {
		localStorage.setItem('quickheadlines-read-mode', readModeState.mode);
	}
}

export function initReadMode(): void {
	if (typeof localStorage !== 'undefined') {
		const saved = localStorage.getItem('quickheadlines-read-mode');
		if (saved === 'read' || saved === 'link') {
			readModeState.mode = saved;
		}
	}
	readModeState.mounted = true;
}