export function createLazyLoader<T>(importFn: () => Promise<{ default: T }>): () => Promise<T> {
	let cached: T | null = null;
	return async (): Promise<T> => {
		if (!cached) {
			const { default: component } = await importFn();
			cached = component;
		}
		return cached;
	};
}