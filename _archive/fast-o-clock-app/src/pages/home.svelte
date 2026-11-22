<script lang="ts">
	import { Capacitor } from '@capacitor/core';
	import {
		Page,
		Navbar,
		NavLeft,
		NavTitle,
		NavTitleLarge,
		NavRight,
		Link,
		// Toolbar,
		Block,
		BlockTitle,
		List,
		ListItem,
		Button,
		Badge
	} from 'framework7-svelte';

	import { AppMeta } from '$lib/app.enum';

	const platform = Capacitor.getPlatform();
	let appTitle = AppMeta.appName;
</script>

<Page name="home">
	<!-- Top Navbar -->
	<Navbar sliding={false}>
		<!-- <NavLeft>
			<Link iconIos="f7:menu" iconMd="material:menu" panelOpen="left" />
		</NavLeft> -->
		<NavTitle sliding class="title">{appTitle} <Badge color="blue">{platform}</Badge></NavTitle>
		<!-- <NavRight>
			<Link iconIos="f7:menu" iconMd="material:menu" panelOpen="right" />
		</NavRight> -->
		<NavTitleLarge style="text-transform: capitalize;"
			>{appTitle} <Badge color="blue">{platform}</Badge></NavTitleLarge
		>
	</Navbar>

	<!-- Page content -->
	<BlockTitle>Fasting</BlockTitle>
	<Block>
		<p>Welcome to the home page of the app. This is the main page of the app.</p>
	</Block>
</Page>
