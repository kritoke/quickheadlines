export const searchState = $state({
	query: '',
	expanded: false
});

export function setSearchQuery(query: string) {
	searchState.query = query;
}

export function openSearch() {
	searchState.expanded = true;
}

export function closeSearch() {
	searchState.expanded = false;
}

export function toggleSearch() {
	searchState.expanded = !searchState.expanded;
}