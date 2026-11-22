<script lang="ts">
	import { ArrowLeft } from 'carbon-icons-svelte';
	import { ListItem, Button, UnorderedList, Link } from 'carbon-components-svelte';

	import { ArticleView, Spacer } from '$lib/components';
	import '$lib/styles/shared.css';
</script>

<ArticleView>
	<div class="panel-content">
		<h2>Copyright</h2>
		<p>© 2025 <b>pinoy.dev</b></p>

		<Spacer />
		<h2>Credits</h2>
		<div class="credits-list">
			<UnorderedList>
				<ListItem>
					Background credits - <Link href="https://unsplash.com/@hipcravo"
						>Unsplash - @hipcravo</Link
					>
				</ListItem>
				<ListItem>
					Icons - <Link href="https://github.com/carbon-design-system/carbon-icons-svelte"
						>IBM - Carbon Design System - Icons</Link
					>
				</ListItem>
			</UnorderedList>
		</div>
		<Spacer showHorizontalRule />
	</div>
	<Spacer />
	<Button
		kind="secondary"
		size="field"
		icon={ArrowLeft}
		href="/"
		iconDescription="Go back"
		style="width: 20%;margin-left: auto;"
	/>
</ArticleView>

<style>
	.panel-content {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding: 1em;
		margin-bottom: 1.5rem;
		width: 100%;
	}

	.credits-list {
		display: flex;
		flex-direction: column;
		font-family: var(--app-font-family-body);
		font-size: 1em;
	}

	h2 {
		font-style: italic;
		font-weight: var(--font-weight-900);
	}
</style>
