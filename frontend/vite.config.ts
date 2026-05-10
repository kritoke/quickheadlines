import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit(),
		{
            name: 'strip-codesplitting-warning',
            // Intercept the config before it hits the bundler
            configResolved(config) {
                const output = config.build.rollupOptions.output;
                if (output) {
                    if (Array.isArray(output)) {
                        output.forEach(o => delete o.codeSplitting);
                    } else {
                        delete output.codeSplitting;
                    }
                }
            }
        }
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
