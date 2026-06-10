import { getStoredValue, setStoredValue } from "$lib/utils/storage";

const STORAGE_KEY = "quickheadlines-read-mode";

export const readModeState = $state({
	mode: "link" as "link" | "read",
	mounted: false,
});

export function toggleReadMode(): void {
	readModeState.mode = readModeState.mode === "link" ? "read" : "link";
	setStoredValue(STORAGE_KEY, readModeState.mode);
}

export function initReadMode(): void {
	const saved = getStoredValue(STORAGE_KEY, "link");
	if (saved === "read" || saved === "link") {
		readModeState.mode = saved;
	}
	readModeState.mounted = true;
}
