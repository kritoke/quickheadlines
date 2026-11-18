let cachedIsIOS: boolean | null = null;

export function isIOS(): boolean {
	if (cachedIsIOS !== null) return cachedIsIOS;
	cachedIsIOS = typeof navigator !== 'undefined' && /iPad|iPhone|iPod/.test(navigator.userAgent);
	return cachedIsIOS;
}
