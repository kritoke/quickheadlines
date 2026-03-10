import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

export function isIOS(): boolean {
	if (typeof navigator === 'undefined') return false;
	return /iPad|iPhone|iPod/.test(navigator.userAgent);
}
