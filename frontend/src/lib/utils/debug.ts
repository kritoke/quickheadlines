import { fetchConfig } from '$lib/api';

let debugEnabled = false;
let configLoaded = false;

export async function initDebug(): Promise<void> {
	if (configLoaded) return;
	
	try {
		const config = await fetchConfig();
		debugEnabled = config.debug ?? false;
		configLoaded = true;
	} catch {
		debugEnabled = false;
		configLoaded = true;
	}
}

export function isDebugEnabled(): boolean {
	return debugEnabled;
}

export function setDebugEnabled(enabled: boolean): void {
	debugEnabled = enabled;
	configLoaded = true;
}

export const logger = {
	log: (...args: unknown[]) => {
		if (debugEnabled) console.log('[DEBUG]', ...args);
	},
	info: (...args: unknown[]) => {
		if (debugEnabled) console.info('[DEBUG]', ...args);
	},
	warn: (...args: unknown[]) => {
		if (debugEnabled) console.warn('[DEBUG]', ...args);
	},
	error: (...args: unknown[]) => {
		if (debugEnabled) console.error('[DEBUG]', ...args);
	}
};
