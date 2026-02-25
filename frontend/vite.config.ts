import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	build: {
		target: 'esnext',
		rollupOptions: {
            onwarn(warning, warn) {
                // Ignore the Rolldown warning about 'codeSplitting'
                if (warning.message.includes('codeSplitting')) return;
                
                // Keep all other warnings
                warn(warning);
            }
        }
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
