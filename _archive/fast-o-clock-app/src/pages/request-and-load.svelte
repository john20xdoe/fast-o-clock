<script lang="ts">
	import { Page, Navbar, Block, List, ListItem } from 'framework7-svelte';

	import type { User } from '$lib/stores/user.svelte';
	let { user } = $props<{ user: User }>();
</script>

<Page>
	<Navbar title={`${user.firstName} ${user.lastName}`} backLink="Back" />
	<Block strong inset>
		{user.about}
	</Block>
	<List strong inset dividersIos>
		{#each user.links as link (link.url)}
			<ListItem link={link.url} title={link.title} external target="_blank" />
		{/each}
	</List>
</Page>
