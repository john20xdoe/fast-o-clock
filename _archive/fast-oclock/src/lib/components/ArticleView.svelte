<script lang="ts">
	import type { SvelteHTMLElements } from 'svelte/elements';

	let { title, children } = $props<SvelteHTMLElements['div']>();
</script>

<article class="article-view">
	<div class="view-header">
		{#if title}
			<h2>
				{title}
			</h2>
		{/if}
	</div>

	<div class="view-content">
		{@render children?.()}
	</div>
</article>

<style>
	.article-view {
		display: flex;
		flex-direction: column;
		flex: 1;
		align-content: flex-start;
		max-width: 375px;
		margin: 0 auto;
	}

	.view-header {
		align-items: center;
		gap: 1em;
		text-align: center;
	}

	.view-header h2 {
		font-size: 2em;
		font-family: var(--app-font-family-headings);
		font-weight: var(--font-weight-900);
		font-style: italic;
		font-variant-ligatures: normal;
		text-shadow: 0 0 1px rgba(0, 0, 0, 0.5);
	}

	.view-content {
		display: flex;
		flex-direction: column;
		border-radius: 0.5em;
		min-height: 100%;
	}
</style>
