import path from 'path';
import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tsconfigPaths from 'vite-tsconfig-paths';

const SRC_DIR = path.resolve(__dirname, './src');
const PUBLIC_DIR = path.resolve(__dirname, './public');
const BUILD_DIR = path.resolve(__dirname, './www');

export default defineConfig({
	plugins: [svelte(), tsconfigPaths()],

	// generated from Framework7 CLI - watch out for deprecation
	root: SRC_DIR,
	base: '',
	publicDir: PUBLIC_DIR,
	build: {
		outDir: BUILD_DIR,
		assetsInlineLimit: 0,
		emptyOutDir: true,
		rollupOptions: {
			treeshake: false
		}
	},
	resolve: {
		alias: {
			'@': SRC_DIR,
			$lib: path.resolve(__dirname, './src/lib')
		}
	}
});
