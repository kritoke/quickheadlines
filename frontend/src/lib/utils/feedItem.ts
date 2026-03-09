export function getFaviconSrc(item: {
	favicon?: string;
	favicon_data?: string;
}): string {
	if (item.favicon_data) {
		if (item.favicon_data.startsWith('internal:')) {
			const iconName = item.favicon_data.replace('internal:', '');
			if (iconName === 'code_icon') return '/code_icon.svg';
			return '/favicon.svg';
		}
		return item.favicon_data;
	}
	if (item.favicon) {
		if (item.favicon.startsWith('internal:')) return '/favicon.svg';
		return item.favicon;
	}
	return '/favicon.svg';
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
