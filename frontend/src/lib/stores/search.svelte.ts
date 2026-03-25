export const searchState = $state({
	query: '',
	expanded: false
});

export function setSearchQuery(query: string) {
	searchState.query = query;
}

export function toggleSearch() {
	searchState.expanded = !searchState.expanded;
	if (!searchState.expanded) {
		searchState.query = '';
	}
}

export function closeSearch() {
	searchState.expanded = false;
	searchState.query = '';
}