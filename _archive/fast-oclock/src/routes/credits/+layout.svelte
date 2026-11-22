<script>
	import { Content } from 'carbon-components-svelte';

	import './+layout.css';

	let { children } = $props();
</script>

<Content class="safe-areas content">
	{@render children()}
</Content>
