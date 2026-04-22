// Memoized favicon cache to prevent repeated calculations
import { sanitizeCssColor } from './validation';

const faviconCache = new Map<string, string>();
const MAX_CACHE_SIZE = 1000; // Limit cache size to prevent memory issues

export interface FaviconItem {
	favicon?: string;
	favicon_data?: string;
	url?: string; // Add url for better caching key
}

export function getFaviconSrc(item: FaviconItem): string {
	const cacheKey = `${item.favicon || ''}-${item.favicon_data || ''}-${item.url || ''}`;
	
	if (faviconCache.has(cacheKey)) {
		return faviconCache.get(cacheKey)!;
	}

	const result = resolveFavicon(item);
	
	if (faviconCache.size >= MAX_CACHE_SIZE) {
		const firstKey = faviconCache.keys().next().value;
		if (firstKey !== undefined) {
			faviconCache.delete(firstKey);
		}
	}
	
	faviconCache.set(cacheKey, result);
	return result;
}

function resolveFavicon(item: FaviconItem): string {
	const data = item.favicon_data || item.favicon;
	if (!data) return '/favicon.svg';
	if (data.startsWith('internal:')) {
		const name = data.replace('internal:', '');
		return name === 'code_icon' ? '/code_icon.svg' : '/favicon.svg';
	}
	return data;
}

export function getHeaderStyle(item: {
	header_color?: string;
	header_text_color?: string;
	header_theme_colors?: { light?: { bg: string; text: string }; dark?: { bg: string; text: string } };
}, isDark: boolean): string {
	if (item.header_theme_colors) {
		const colors = isDark ? item.header_theme_colors.dark : item.header_theme_colors.light;
		if (colors) {
			return `background-color: ${sanitizeCssColor(colors.bg, '#64748b')}; color: ${sanitizeCssColor(colors.text, '#ffffff')};`;
		}
	}
	
	const bgColor = sanitizeCssColor(item.header_color || '#64748b', '#64748b');
	const textColor = sanitizeCssColor(item.header_text_color || '#ffffff', '#ffffff');
	return `background-color: ${bgColor}; color: ${textColor};`;
}