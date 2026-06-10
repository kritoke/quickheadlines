import { fetchConfig } from "$lib/api";

/**
 * Shared config loader for stores that track refreshMinutes.
 * Fetches config and applies refresh_minutes to the given store state.
 * Returns the refresh minutes, defaulting to 10 on error.
 */
export async function loadConfigForStore<T extends { refreshMinutes: number }>(
	state: T,
	setRefreshMinutes: (state: T, minutes: number) => T,
): Promise<number> {
	try {
		const config = await fetchConfig();
		const minutes = config.refresh_minutes || 10;
		Object.assign(state, setRefreshMinutes(state, minutes));
		return minutes;
	} catch {
		return 10;
	}
}
