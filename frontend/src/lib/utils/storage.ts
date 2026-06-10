/**
 * Safe localStorage wrapper that handles private browsing and unavailable storage.
 * Eliminates the repeated try/catch pattern across stores.
 */

export function getStoredValue(key: string, fallback: string): string {
	if (typeof window === "undefined") return fallback;
	try {
		return localStorage.getItem(key) || fallback;
	} catch {
		return fallback;
	}
}

export function setStoredValue(key: string, value: string): void {
	if (typeof window === "undefined") return;
	try {
		localStorage.setItem(key, value);
	} catch {
		// localStorage not available (private browsing)
	}
}

export function removeStoredValue(key: string): void {
	if (typeof window === "undefined") return;
	try {
		localStorage.removeItem(key);
	} catch {
		// localStorage not available
	}
}

export function getStoredBoolean(key: string, fallback: boolean): boolean {
	if (typeof window === "undefined") return fallback;
	try {
		const value = localStorage.getItem(key);
		if (value === null) return fallback;
		return value !== "false";
	} catch {
		return fallback;
	}
}

export function getStoredInt(
	key: string,
	fallback: number,
	validValues?: Set<string>,
): number {
	if (typeof window === "undefined") return fallback;
	try {
		const value = localStorage.getItem(key);
		if (value === null) return fallback;
		if (validValues && !validValues.has(value)) return fallback;
		const parsed = parseInt(value);
		return isNaN(parsed) ? fallback : parsed;
	} catch {
		return fallback;
	}
}
