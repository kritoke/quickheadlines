/**
 * URL and color validation utilities for security
 */

export function isValidUrl(url: string): boolean {
  try {
    const urlObj = new URL(url, window.location.origin);
    // Only allow http and https protocols
    return ['http:', 'https:'].includes(urlObj.protocol);
  } catch {
    return false;
  }
}

export function isValidCssColor(color: string): boolean {
  if (!color) return false;
  
  // Check for common CSS color formats
  const cssColorPatterns = [
    /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/, // Hex colors
    /^rgb\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*\)$/, // rgb()
    /^rgba\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*(0|1|0?\.\d+)\s*\)$/, // rgba()
    /^(red|green|blue|yellow|orange|purple|pink|magenta|cyan|teal|lime|black|white|gray|grey|silver|maroon|olive|navy|fuchsia|aqua)$/, // Named colors
    /^hsl\(\s*\d{1,3}\s*,\s*\d{1,3}%\s*,\s*\d{1,3}%\s*\)$/, // hsl()
    /^hsla\(\s*\d{1,3}\s*,\s*\d{1,3}%\s*,\s*\d{1,3}%\s*,\s*(0|1|0?\.\d+)\s*\)$/ // hsla()
  ];
  
  return cssColorPatterns.some(pattern => pattern.test(color.trim()));
}

export function sanitizeUrl(url: string, fallback: string = '#'): string {
  if (isValidUrl(url)) {
    return url;
  }
  return fallback;
}

export function sanitizeCssColor(color: string, fallback: string = '#64748b'): string {
  if (isValidCssColor(color)) {
    return color;
  }
  return fallback;
}