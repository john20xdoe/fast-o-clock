<script lang="ts">
	import { Page, Navbar, List, ListItem, Block, Button } from 'framework7-svelte';
	import { productState, addProduct, type Product } from '../lib/stores/product.svelte';

	let products = $derived(productState.products);

	const sampleProduct: Product = {
		id: '4',
		title: 'Apple iPhone 12',
		description:
			'Lorem ipsum dolor sit amet, consectetur adipisicing elit. Nisi tempora similique reiciendis, error nesciunt vero, blanditiis pariatur dolor, minima sed sapiente rerum, dolorem corrupti hic modi praesentium unde saepe perspiciatis.'
	};
</script>

<Page name="catalog">
	<Navbar title="Catalog" />
	<List strong dividersIos outlineIos insetMd>
		{#each products as product (product.id)}
			<ListItem title={product.title} link={`/product/${product.id}/`} />
		{/each}
	</List>
	{#if products.length <= 3}
		<Block>
			<Button fill onClick={() => addProduct(sampleProduct)}>Add Product</Button>
		</Block>
	{/if}
</Page>
