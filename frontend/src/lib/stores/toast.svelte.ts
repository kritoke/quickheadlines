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

export const toastStore = {
	get toasts() {
		return toasts;
	},
	
	add(toast: Omit<ToastMessage, 'id'>) {
		const id = crypto.randomUUID();
		toasts.push({ ...toast, id });
		
		// Auto-remove after duration (default 5000ms)
		const duration = toast.duration ?? 5000;
		if (duration > 0) {
			setTimeout(() => this.remove(id), duration);
		}
	},
	
	remove(id: string) {
		toasts.splice(toasts.findIndex(t => t.id === id), 1);
	},
	
	clear() {
		toasts.length = 0;
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