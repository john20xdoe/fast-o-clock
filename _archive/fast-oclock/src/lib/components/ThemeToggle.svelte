<script lang="ts">
	import { Toggle } from 'carbon-components-svelte';
	import { themeStore } from '$lib/states/theme.svelte';

	let isLightMode = $state(themeStore.theme === 'g10');

	$effect(() => {
		themeStore.theme = isLightMode ? 'g10' : 'g100';
	});
</script>

<Toggle labelA="Dark Mode" labelB="Light Mode" bind:toggled={isLightMode} />
