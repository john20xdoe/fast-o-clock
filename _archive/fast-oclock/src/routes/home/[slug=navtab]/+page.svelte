<script lang="ts">
	import { HomePanels } from '$lib';

	import { FastingSection, YouSection } from '$lib/sections';
	import '$lib/styles/shared.css';

	// inherited from parent layout load()
	let { data } = $props();
	let currentTab = $derived(data.activeTab);
</script>

<div class="panel-content">
	<p>{currentTab.description}</p>
	{#if currentTab.value === HomePanels.FASTING}
		<FastingSection />
	{:else if currentTab.value === HomePanels.TIMELINE}
		<p>TIMELINE SECTION HERE</p>
	{:else if currentTab.value === HomePanels.YOU}
		<YouSection />
	{/if}
</div>

<style>
	.panel-content {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding: 1rem;
		margin-bottom: 1.5rem;
		width: 100%;
	}

	.panel-content p {
		margin-bottom: 1rem;
	}
</style>
