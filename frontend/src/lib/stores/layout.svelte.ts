export type ColumnCount = 1 | 2 | 3 | 4;

export const columnOptions: { id: ColumnCount; name: string; description: string }[] = [
	{ id: 1, name: '1 Column', description: 'Single column layout' },
	{ id: 2, name: '2 Columns', description: 'Two column layout' },
	{ id: 3, name: '3 Columns', description: 'Three column layout' },
	{ id: 4, name: '4 Columns', description: 'Four column layout' }
];

export const layoutState = $state({
	timelineColumns: 1 as ColumnCount,
	mounted: false
});

export function initLayout() {
	if (typeof window === 'undefined') return;

	const savedColumns = localStorage.getItem('quickheadlines-timeline-columns');
	if (savedColumns && ['1', '2', '3', '4'].includes(savedColumns)) {
		layoutState.timelineColumns = parseInt(savedColumns) as ColumnCount;
	}

	layoutState.mounted = true;
}

export function setTimelineColumns(count: ColumnCount) {
	layoutState.timelineColumns = count;
	localStorage.setItem('quickheadlines-timeline-columns', String(count));
}
