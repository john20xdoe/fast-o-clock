<script lang="ts">
	let { showHorizontalRule } = $props<{
		showHorizontalRule?: boolean;
	}>();
</script>

{#if showHorizontalRule}
	<div class="bordered spacer"></div>
{:else}
	<div class="spacer"></div>
{/if}

<style>
	.spacer {
		display: block;
		margin: var(--gap, auto) auto;
		/* margin-top: auto; */
		width: 100%;
		height: 0;
		padding: 0;
	}

	.bordered {
		border-top: 1px solid #444;
		margin: 0.5em 0;
	}
</style>
