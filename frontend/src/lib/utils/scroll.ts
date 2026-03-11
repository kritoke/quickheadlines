export function scrollToTop(): void {
	window.scrollTo({ top: 0, behavior: 'auto' });
}

export function scrollToPosition(y: number): void {
	window.scrollTo({ top: y, behavior: 'auto' });
}
