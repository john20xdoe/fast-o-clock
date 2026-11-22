<script lang="ts">
	import { goto } from '$app/navigation';
	import { Button } from 'carbon-components-svelte';
	import { ArrowRight } from 'carbon-icons-svelte';
	import { AppMeta } from '$lib';
	import { userDataStore } from '$lib/states/user-data.svelte';

	import '$lib/styles/shared.css';

	const title = AppMeta.appName;
	const slogan = AppMeta.appSlogan;
	const description = AppMeta.appDescription;

	let user = userDataStore;
	$effect(() => {
		// TEMP: initialize autoredirect to home
		if (user.isOnboarded) {
			goto('/home');
		}
	});
</script>

<section class="splash">
	<div class="splash-header">
		<h1>{title}</h1>
		<h6>{slogan}</h6>
	</div>

	<div class="splash-content">
		<h3>{description}</h3>
		<Button href="/home" kind="primary" size="field" style="width: 100%;">
			<ArrowRight slot="icon" size={32} style="margin-left: auto" />
			<h5>Let's Go</h5>
		</Button>
	</div>
	<footer class="splash-footer">
		<Button href="/credits" kind="ghost" size="small" style="text-align: center">Credits</Button>
	</footer>
</section>

<style>
	.splash {
		background-image: url('https://images.unsplash.com/photo-1550345332-09e3ac987658?dpr=1&q=75&auto=format&fit=fill&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D');
		background-size: cover;
		background-position: left;
		background-repeat: no-repeat;
		height: 100%;
		padding: 0.15em;
		padding-top: var(--app-safe-area-top);
		padding-bottom: var(--app-safe-area-bottom);
		border-radius: 0.55em;
		display: flex;
		flex-direction: column;
		gap: 1em;
	}

	.splash-header {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;

		margin-top: 30%;
		text-align: center;
		box-sizing: border-box;
		padding: 0.1em;
	}
	h1,
	h3 {
		text-shadow: 0 1px 10px var(--cds-text-inverse);
	}

	h1 {
		font-size: 2.75em;
		font-family: var(--app-font-family-headings);
		font-weight: var(--font-weight-900);
		font-style: italic;
		color: var(--cds-text-01);
		font-variant-ligatures: normal;
	}

	h6 {
		text-transform: uppercase;
		font-size: 0.95em;
		color: var(--cds-support-04);
		font-family: var(--app-font-family-body);
		font-weight: var(--font-weight-600);
		font-variant-ligatures: normal;
		letter-spacing: 0.05em;
	}

	h3 {
		font-size: 1.2em;
		text-align: center;
		text-shadow: 0 1px 1px var(--cds-text-inverse);
	}

	.splash-content {
		display: flex;
		flex: 1;
		flex-direction: column;
		justify-content: space-between;
		align-items: flex-start;

		text-align: center;
		border-radius: 0.55em;
		padding: 2em;
		margin: 1em auto;
		background-color: #4444444a;
		-webkit-backdrop-filter: blur(0.75em);
		backdrop-filter: blur(0.75em);
		box-shadow: 0 1px 10px var(--cds-text-inverse);
		border: 1px solid #ffffff66;
		border-top: 1px solid #ffffffaa;
		border-bottom: 1px solid #444444ff;
	}

	.splash-footer {
		display: flex;
		justify-content: center;
		flex-direction: column;
		align-items: center;
		text-align: center;
		margin-top: auto;
	}
</style>
