import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { optimizeImports } from 'carbon-preprocess-svelte';

const buildFolder = 'dist'; // overrides default 'build' folder output by "yarn build"
const config = {
	preprocess: [vitePreprocess(), optimizeImports()],
	kit: {
		adapter: adapter({
			pages: buildFolder,
			assets: buildFolder,
			fallback: 'index.html',
			precompress: false,
			strict: true
		})
	}
};

export default config;
