import { describe, it, expect } from 'vitest';
import { isValidUrl, sanitizeUrl } from './validation';

describe('isValidUrl / sanitizeUrl (reader + feed links)', () => {
	it.each([
		'javascript:alert(1)',
		'JavaScript:alert(1)',
		' javascript:alert(1)',
		'data:text/html,<script>alert(1)</script>',
		'vbscript:msgbox(1)',
	])('rejects %s', (url) => {
		expect(isValidUrl(url)).toBe(false);
		expect(sanitizeUrl(url)).toBe('#');
	});

	it.each(['https://example.com/a', 'http://example.com/?q=1', '/relative/path'])('accepts %s', (url) => {
		expect(isValidUrl(url)).toBe(true);
	});
});
