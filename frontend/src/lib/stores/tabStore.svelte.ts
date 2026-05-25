/**
 * Tab Persistence Store
 * 
 * Manages the active tab selection with localStorage persistence.
 * This ensures the selected tab persists across page navigations and browser refreshes.
 */

const TAB_STORAGE_KEY = 'quickheadlines-active-tab';

/**
 * Get the stored tab from localStorage.
 * Falls back to 'all' if no tab is stored or localStorage is unavailable.
 */
export function getStoredTab(): string {
	if (typeof window === 'undefined') return 'all';
	try {
		return localStorage.getItem(TAB_STORAGE_KEY) || 'all';
	} catch {
		return 'all';
	}
}

/**
 * Save the active tab to localStorage.
 * Silently fails if localStorage is unavailable (e.g., private browsing).
 */
export function saveTab(tab: string): void {
	if (typeof window === 'undefined') return;
	try {
		localStorage.setItem(TAB_STORAGE_KEY, tab);
	} catch {
		// localStorage not available
	}
}

/**
 * Initialize the tab state from localStorage.
 * Called during app startup to restore the previously selected tab.
 */
export function initTabState(): string {
	return getStoredTab();
}

/**
 * Clear the stored tab (resets to 'all').
 */
export function clearStoredTab(): void {
	if (typeof window === 'undefined') return;
	try {
		localStorage.removeItem(TAB_STORAGE_KEY);
	} catch {
		// localStorage not available
	}
}
