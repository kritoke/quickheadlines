// Memoized favicon cache to prevent repeated calculations
import { sanitizeCssColor } from "./validation";

const faviconCache = new Map<string, string>();
const MAX_CACHE_SIZE = 1000; // Limit cache size to prevent memory issues

export interface FaviconItem {
	favicon?: string;
	favicon_data?: string;
	url?: string; // Add url for better caching key
}

export function getFaviconSrc(item: FaviconItem): string {
	const cacheKey = `${item.favicon || ""}-${item.favicon_data || ""}-${item.url || ""}`;

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
	if (!data) return "/favicon.svg";
	if (data.startsWith("internal:")) {
		const name = data.replace("internal:", "");
		return name === "code_icon" ? "/code_icon.svg" : "/favicon.svg";
	}
	return data;
}

export interface ThemeColorItem {
	header_color?: string;
	header_text_color?: string;
	header_theme_colors?: {
		light?: { bg: string; text: string };
		dark?: { bg: string; text: string };
	};
}

export function resolveThemeColors(
	item: ThemeColorItem,
	isDark: boolean,
): { bg: string; text: string } | null {
	if (!item.header_theme_colors) return null;
	const colors = isDark
		? item.header_theme_colors.dark
		: item.header_theme_colors.light;
	if (!colors) return null;
	return {
		bg: sanitizeCssColor(colors.bg, "#64748b"),
		text: sanitizeCssColor(colors.text, "#ffffff"),
	};
}

export function getHeaderStyle(item: ThemeColorItem, isDark: boolean): string {
	const themeColors = resolveThemeColors(item, isDark);
	if (themeColors) {
		return `background-color: ${themeColors.bg}; color: ${themeColors.text};`;
	}

	const bgColor = sanitizeCssColor(item.header_color || "#64748b", "#64748b");
	const textColor = sanitizeCssColor(
		item.header_text_color || "#ffffff",
		"#ffffff",
	);
	return `background-color: ${bgColor}; color: ${textColor};`;
}

export function getFaviconBgStyle(
	item: ThemeColorItem,
	isDark: boolean,
): string {
	const themeColors = resolveThemeColors(item, isDark);
	if (themeColors?.text) {
		return `background-color: ${themeColors.text}20; border-color: ${themeColors.text}40`;
	}
	return "background-color: #e2e8f0; border-color: #cbd5e1";
}
