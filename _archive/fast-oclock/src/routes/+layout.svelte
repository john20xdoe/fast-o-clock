<script lang="ts">
	import 'carbon-components-svelte/css/all.css';
	import '@capacitor-community/safe-area';

	import {
		// themes,
		themeStore,
		initialTheme
	} from '$lib/states/theme.svelte';
	import { Theme } from 'carbon-components-svelte';
	import { initialize } from '@capacitor-community/safe-area';

	$effect(() => {
		// TODO: fix syncing of persistKey to storage and toggle
		// const savedTheme = localStorage.getItem('__app-theme') as typeof initialTheme | null;
		// themeStore.theme = savedTheme && themes.includes(savedTheme) ? savedTheme : initialTheme;

		document.documentElement.setAttribute('theme', themeStore?.theme ?? initialTheme);
	});
	initialize();
	let { children } = $props();
</script>

<main class="app">
	<Theme theme={themeStore.theme} />
	{@render children()}
</main>
