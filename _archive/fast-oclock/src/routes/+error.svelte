<script lang="ts">
	import { page } from '$app/state';
	import { ArticleView } from '$lib';
</script>

<ArticleView title="Error">
	<h1>{page.status}: {page.error?.message}</h1>
</ArticleView>
