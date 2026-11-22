<script lang="ts">
	import { Content } from 'carbon-components-svelte';
	import { ArticleView, NavTab, Spacer } from '$lib/components';
	// import { setContext } from 'svelte';
	import { HomePanels } from '$lib';

	import './+layout.css';
	import { goto } from '$app/navigation';

	let { data, children } = $props();
	let tabs = $derived(data.tabs);

	let selectedIndex = $derived(tabs.findIndex((tab) => data.activeTab.value === tab.value));
	// TODO: also preload user data here
	// setContext('user', () => data.user);

	const setSelectedIndex = (index: HomePanels) => {
		selectedIndex = index;
		goto(`/home/${tabs[index].href}`);
	};
</script>

<Content class="safe-areas content">
	<ArticleView title={tabs[selectedIndex].text}>
		{@render children()}

		<Spacer />
		<NavTab {tabs} currentTab={selectedIndex} onSelect={setSelectedIndex} />
	</ArticleView>
</Content>
