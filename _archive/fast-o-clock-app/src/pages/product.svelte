<script lang="ts">
	import type { Router } from 'framework7/types';

	import { Page, Navbar, BlockTitle, Block, Button } from 'framework7-svelte';
	import { productState, deleteProduct } from '../lib/stores/product.svelte';

	let { f7route, f7router } = $props<{
		f7route: Router.Route;
		f7router: Router.Router;
	}>();
	const productId = f7route.params.id;
	const products = productState.products;
	let currentProduct = $derived.by(() => {
		return products.find((product) => product.id === productId);
	});

	const handleDeleteProduct = () => {
		deleteProduct(productId);
		f7router.back();
	};
</script>

<Page name="product">
	{#if currentProduct}
		<Navbar title={currentProduct.title} backLink="Back" />
		<BlockTitle>About {currentProduct.title}</BlockTitle>
		<Block>
			{currentProduct.description}
		</Block>
		<Button onClick={handleDeleteProduct}>Delete</Button>
	{:else}
		<Navbar title="Product not found" backLink="Back" />
		<BlockTitle>Product not found</BlockTitle>
		<Block>Product not found</Block>
	{/if}
</Page>
