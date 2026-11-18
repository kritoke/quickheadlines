import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';

// SvelteKit 3: configuration lives here (svelte.config.js is no longer read).
export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit({
			preprocess: vitePreprocess(),
			// SPA mode: static build with index.html fallback, served by the Crystal binary
			adapter: adapter({
				pages: 'dist',
				assets: 'dist',
				fallback: 'index.html',
				precompress: false,
				strict: true
			}),
			paths: {
				relative: false
			}
		})
	],

	build: {
		target: 'es2022',
	},
	server: {
		port: 5173,
		proxy: {
			'/api': 'http://localhost:8080',
			'/favicons': 'http://localhost:8080',
			'/fonts': 'http://localhost:8080'
		}
	}
});
