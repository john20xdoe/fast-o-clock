import { sveltekit } from '@sveltejs/kit/vite';
import { optimizeCss } from 'carbon-preprocess-svelte';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit(), optimizeCss()],
	server: {
		watch: {
			ignored: ['**/ios/**', '**/android/**', '**/dist/**']
		}
	}
});
