export type ToastType = 'default' | 'success' | 'error' | 'warning' | 'info';

export interface ToastMessage {
	id: string;
	type: ToastType;
	title?: string;
	description: string;
	duration?: number;
	onAction?: () => void;
	actionLabel?: string;
}

// Use top-level $state for reactivity
const toasts = $state<ToastMessage[]>([]);
const timeoutIds = new Set<number>();

function generateUUID(): string {
	// Check if crypto.randomUUID is available (modern browsers)
	if (typeof crypto !== 'undefined' && crypto.randomUUID) {
		try { return crypto.randomUUID(); } catch { /* fallback below */ }
	}
	
	// Fallback for older browsers/IOS Safari
	// Simple UUID v4 generator
	const randomValues = new Array(16);
	for (let i = 0; i < 16; i++) {
		randomValues[i] = Math.floor(Math.random() * 256);
	}
	
	// Set version to 4 (bits 12-15 of time_hi_and_version)
	randomValues[6] = (randomValues[6] & 0x0f) | 0x40;
	// Set variant to 2 (bits 6-7 of clock_seq_hi_and_reserved)
	randomValues[8] = (randomValues[8] & 0x3f) | 0x80;
	
	return [
		randomValues[0].toString(16).padStart(2, '0'),
		randomValues[1].toString(16).padStart(2, '0'),
		randomValues[2].toString(16).padStart(2, '0'),
		randomValues[3].toString(16).padStart(2, '0'),
		'-',
		randomValues[4].toString(16).padStart(2, '0'),
		randomValues[5].toString(16).padStart(2, '0'),
		'-',
		randomValues[6].toString(16).padStart(2, '0'),
		randomValues[7].toString(16).padStart(2, '0'),
		'-',
		randomValues[8].toString(16).padStart(2, '0'),
		randomValues[9].toString(16).padStart(2, '0'),
		'-',
		randomValues[10].toString(16).padStart(2, '0'),
		randomValues[11].toString(16).padStart(2, '0'),
		randomValues[12].toString(16).padStart(2, '0'),
		randomValues[13].toString(16).padStart(2, '0'),
		randomValues[14].toString(16).padStart(2, '0'),
		randomValues[15].toString(16).padStart(2, '0')
	].join('');
}

export const toastStore = {
	get toasts() {
		return toasts;
	},
	
	add(toast: Omit<ToastMessage, 'id'>) {
		const id = generateUUID();
		toasts.push({ ...toast, id });
		
		// Auto-remove after duration (default 5000ms)
		const duration = toast.duration ?? 5000;
		if (duration > 0) {
			const timeoutId = setTimeout(() => {
				timeoutIds.delete(timeoutId);
				this.remove(id);
			}, duration);
			timeoutIds.add(timeoutId);
		}
	},
	
	remove(id: string) {
		toasts.splice(toasts.findIndex(t => t.id === id), 1);
	},
	
	clear() {
		toasts.length = 0;
		// Clear all pending timeouts
		for (const timeoutId of timeoutIds) {
			clearTimeout(timeoutId);
		}
		timeoutIds.clear();
	},
	
	// Convenience methods
	error(description: string, title?: string) {
		this.add({ type: 'error', description, title });
	},
	
	success(description: string, title?: string) {
		this.add({ type: 'success', description, title });
	},
	
	warning(description: string, title?: string) {
		this.add({ type: 'warning', description, title });
	},
	
	info(description: string, title?: string) {
		this.add({ type: 'info', description, title });
	},
	
	default(description: string, title?: string) {
		this.add({ type: 'default', description, title });
	}
};