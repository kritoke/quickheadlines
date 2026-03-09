export function deepClone<T>(obj: T): T {
	if (typeof structuredClone === 'function') {
		return structuredClone(obj);
	}
	
	if (obj === null || typeof obj !== 'object') {
		return obj;
	}
	
	if (obj instanceof Date) {
		return new Date(obj.getTime()) as T;
	}
	
	if (obj instanceof Map) {
		const clonedMap = new Map();
		for (const [key, value] of obj) {
			clonedMap.set(deepClone(key), deepClone(value));
		}
		return clonedMap as T;
	}
	
	if (obj instanceof Set) {
		const clonedSet = new Set();
		for (const value of obj) {
			clonedSet.add(deepClone(value));
		}
		return clonedSet as T;
	}
	
	if (Array.isArray(obj)) {
		return obj.map(item => deepClone(item)) as T;
	}
	
	if (typeof obj === 'object') {
		const clonedObj: Record<string, unknown> = {};
		for (const key in obj) {
			if (Object.prototype.hasOwnProperty.call(obj, key)) {
				clonedObj[key] = deepClone((obj as Record<string, unknown>)[key]);
			}
		}
		return clonedObj as T;
	}
	
	return obj;
}
