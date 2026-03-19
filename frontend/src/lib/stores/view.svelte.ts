import { SvelteSet } from 'svelte/reactivity';

type ViewState = {
	currentView: 'feeds' | 'tab-timeline' | 'global-timeline';
};

const initialState: ViewState = {
	currentView: 'feeds'
};

export const viewState = $state<ViewState>({ ...initialState });

export function setView(view: 'feeds' | 'tab-timeline' | 'global-timeline'): void {
	viewState.currentView = view;
}

export function getCurrentView(): 'feeds' | 'tab-timeline' | 'global-timeline' {
	return viewState.currentView;
}