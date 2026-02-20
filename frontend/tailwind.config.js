/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	darkMode: 'class',
	theme: {
		extend: {
			fontFamily: {
				sans: ['Inter var', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif']
			},
			colors: {
				slate: {
					50: '#f8fafc',
					100: '#f1f5f9',
					200: '#e2e8f0',
					300: '#cbd5e1',
					400: '#94a3b8',
					500: '#64748b',
					600: '#475569',
					700: '#334155',
					800: '#1e293b',
					900: '#0f172a',
					950: '#020617'
				},
				luxe: {
					light: '#fcfcfd',
					dark: '#09090b',
					border: 'rgba(0, 0, 0, 0.08)',
					'border-dark': 'rgba(255, 255, 255, 0.1)'
				},
				accent: {
					DEFAULT: '#96ad8d',
					glow: 'rgba(150, 173, 141, 0.3)'
				}
			},
			boxShadow: {
				'inner-light': 'inset 0 1px 2px 0 rgba(0, 0, 0, 0.05)',
				'inner-dark': 'inset 0 1px 0 0 rgba(255, 255, 255, 0.05)',
				'luxe-glow': '0 0 20px -5px rgba(150, 173, 141, 0.4)'
			}
		}
	},
	plugins: []
};
