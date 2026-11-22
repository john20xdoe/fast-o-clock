<script lang="ts" generics="TValue extends number">
	import { ContentSwitcher, Switch } from 'carbon-components-svelte';

	import type { NavTabItem } from '$lib/types';
	type NavTabProps<TValue> = {
		tabs: NavTabItem<TValue>[];
		currentTab: TValue;
		onSelect: (index: TValue) => void;
	};

	let { currentTab, tabs, onSelect }: NavTabProps<TValue> = $props();

	let selectedIndex = $derived(tabs.findIndex((tab) => tab.value === currentTab));
</script>

<div class="switcher">
	<ContentSwitcher
		size="xl"
		on:change={(event) => onSelect(tabs[event.detail].value)}
		{selectedIndex}
	>
		{#each tabs as tab, i (tab.value)}
			<Switch value={i}>
				<div style="display: flex; align-items: center; gap: 0.5em">
					{#if tab.icon}
						<tab.icon size={32} />
					{/if}

					{tab.text}
				</div>
			</Switch>
		{/each}
	</ContentSwitcher>
</div>

<style>
	.switcher {
		border-radius: 0.55em;
		margin-bottom: 1em;
		width: 98%;
		margin: 2rem auto;
	}
</style>
