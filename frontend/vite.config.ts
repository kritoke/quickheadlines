import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	build: {
		target: 'esnext'
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
