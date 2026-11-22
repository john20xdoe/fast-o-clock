import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

const config = {
	preprocess: [vitePreprocess({ script: true })],
	vitePlugin: {
		prebundleSvelteLibraries: false
	}
};

export default config;
