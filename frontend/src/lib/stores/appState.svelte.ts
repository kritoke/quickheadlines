import type { TabResponse } from '$lib/types';
import { fetchFeeds, fetchTabs } from '$lib/api';

export const appState = $state({
	tabs: [] as TabResponse[],
	activeTab: 'all',
	loading: false,
	initialized: false
});

export function setTabs(newTabs: TabResponse[]) {
	appState.tabs = newTabs;
	appState.initialized = true;
}

export function setActiveTab(tab: string) {
	appState.activeTab = tab;
}

export function setLoading(isLoading: boolean) {
	appState.loading = isLoading;
}

export async function loadAppTabs(): Promise<void> {
	if (appState.loading) return;
	
	appState.loading = true;
	try {
		const response = await fetchTabs();
		appState.tabs = response.tabs;
		const urlParams = new URLSearchParams(window.location.search);
		appState.activeTab = urlParams.get('tab') || 'all';
		appState.initialized = true;
	} catch (e) {
		console.error('[AppState] Failed to load tabs:', e);
	} finally {
		appState.loading = false;
	}
}

export function resetAppState() {
	appState.tabs = [];
	appState.activeTab = 'all';
	appState.loading = false;
	appState.initialized = false;
}