// Memoized favicon cache to prevent repeated calculations
const faviconCache = new Map<string, string>();
const MAX_CACHE_SIZE = 1000; // Limit cache size to prevent memory issues

export interface FaviconItem {
	favicon?: string;
	favicon_data?: string;
	url?: string; // Add url for better caching key
}

export function getFaviconSrc(item: FaviconItem): string {
	// Create a cache key based on all relevant properties
	const cacheKey = `${item.favicon || ''}-${item.favicon_data || ''}-${item.url || ''}`;
	
	if (faviconCache.has(cacheKey)) {
		return faviconCache.get(cacheKey)!;
	}
	
	let result = '/favicon.svg';
	
	if (item.favicon_data) {
		if (item.favicon_data.startsWith('internal:')) {
			const iconName = item.favicon_data.replace('internal:', '');
			if (iconName === 'code_icon') result = '/code_icon.svg';
			else result = '/favicon.svg';
		} else {
			result = item.favicon_data;
		}
	} else if (item.favicon) {
		if (item.favicon.startsWith('internal:')) {
			result = '/favicon.svg';
		} else {
			result = item.favicon;
		}
	}
	
	// Manage cache size
	if (faviconCache.size >= MAX_CACHE_SIZE) {
		// Remove oldest entry (first inserted)
		const firstKey = faviconCache.keys().next().value;
		if (firstKey !== undefined) {
			faviconCache.delete(firstKey);
		}
	}
	
	faviconCache.set(cacheKey, result);
	return result;
}

export function getHeaderStyle(item: {
	header_color?: string;
	header_text_color?: string;
	header_theme_colors?: { light?: { bg: string; text: string }; dark?: { bg: string; text: string } };
}, isDark: boolean): string {
	if (item.header_theme_colors) {
		const colors = isDark ? item.header_theme_colors.dark : item.header_theme_colors.light;
		if (colors) {
			return `background-color: ${colors.bg}; color: ${colors.text};`;
		}
	}
	
	const bgColor = item.header_color || '#64748b';
	const textColor = item.header_text_color || '#ffffff';
	return `background-color: ${bgColor}; color: ${textColor};`;
}
