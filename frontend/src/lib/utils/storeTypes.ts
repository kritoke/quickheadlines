export type LoadStatus = 'idle' | 'loading' | 'refreshing' | 'error';

export type BaseState<S extends LoadStatus> = {
	status: S;
};

export function isIdle<S extends LoadStatus>(state: { status: S }): state is { status: 'idle' } & BaseState<'idle'> {
	return state.status === 'idle';
}

export function isLoading<S extends LoadStatus>(state: { status: S }): state is { status: 'loading' } & BaseState<'loading'> {
	return state.status === 'loading';
}

export function isRefreshing<S extends LoadStatus>(state: { status: S }): state is { status: 'refreshing' } & BaseState<'refreshing'> {
	return state.status === 'refreshing';
}

export function isError<S extends LoadStatus>(state: { status: S }): state is { status: 'error'; error: string } & BaseState<'error'> {
	return state.status === 'error';
}

export function getError<S extends LoadStatus>(state: { status: S } & ({ error: string } | Record<string, unknown>)): string | null {
	if (state.status === 'error' && 'error' in state && typeof state.error === 'string') {
		return state.error;
	}
	return null;
}
