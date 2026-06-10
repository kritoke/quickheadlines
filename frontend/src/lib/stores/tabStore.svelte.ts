/**
 * Tab Persistence Store
 *
 * Manages the active tab selection with localStorage persistence.
 * This ensures the selected tab persists across page navigations and browser refreshes.
 */

import {
	getStoredValue,
	setStoredValue,
	removeStoredValue,
} from "$lib/utils/storage";

const TAB_STORAGE_KEY = "quickheadlines-active-tab";

/**
 * Get the stored tab from localStorage.
 * Falls back to 'all' if no tab is stored or localStorage is unavailable.
 */
export function getStoredTab(): string {
	return getStoredValue(TAB_STORAGE_KEY, "all");
}

/**
 * Save the active tab to localStorage.
 * Silently fails if localStorage is unavailable (e.g., private browsing).
 */
export function saveTab(tab: string): void {
	setStoredValue(TAB_STORAGE_KEY, tab);
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
	removeStoredValue(TAB_STORAGE_KEY);
}
