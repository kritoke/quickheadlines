import { getStoredInt, setStoredValue } from "$lib/utils/storage";

// Grid classes live in tokens/grid.ts as complete string literals so Tailwind
// can see them; re-exported here for existing importers.
export { getFeedGridClass } from "$lib/tokens/grid";

export type ColumnCount = 1 | 2 | 3 | 4;

const VALID_TIMELINE_COLUMNS = new Set(["1", "2", "3", "4"]);
const VALID_FEED_COLUMNS = new Set(["2", "3", "4"]);

export const columnOptions: {
	id: ColumnCount;
	name: string;
	description: string;
}[] = [
	{ id: 2, name: "2 Columns", description: "Two column layout" },
	{ id: 3, name: "3 Columns", description: "Three column layout" },
	{ id: 4, name: "4 Columns", description: "Four column layout" },
];

export const layoutState = $state({
	timelineColumns: 1 as ColumnCount,
	feedColumns: 3 as ColumnCount,
	mounted: false,
});

export function initLayout() {
	if (typeof window === "undefined") return;

	layoutState.timelineColumns = getStoredInt(
		"quickheadlines-timeline-columns",
		1,
		VALID_TIMELINE_COLUMNS,
	) as ColumnCount;
	layoutState.feedColumns = getStoredInt(
		"quickheadlines-feed-columns",
		3,
		VALID_FEED_COLUMNS,
	) as ColumnCount;
	layoutState.mounted = true;
}

export function setTimelineColumns(count: ColumnCount) {
	layoutState.timelineColumns = count;
	setStoredValue("quickheadlines-timeline-columns", String(count));
}

export function setFeedColumns(count: ColumnCount) {
	layoutState.feedColumns = count;
	setStoredValue("quickheadlines-feed-columns", String(count));
}
