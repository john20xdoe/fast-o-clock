export type Product = {
	id: string;
	title: string;
	description: string;
};

// TODO: this replaces Framework7's createStore() implementation
// Let's see if we can still use Framework7 with Svelte 5' $state instead.
export const productState = $state<{ products: Product[] }>({
	products: [
		{
			id: '1',
			title: 'Apple iPhone 8',
			description:
				'Lorem ipsum dolor sit amet, consectetur adipisicing elit. Nisi tempora similique reiciendis, error nesciunt vero, blanditiis pariatur dolor, minima sed sapiente rerum, dolorem corrupti hic modi praesentium unde saepe perspiciatis.'
		},
		{
			id: '2',
			title: 'Apple iPhone 8 Plus',
			description:
				'Velit odit autem modi saepe ratione totam minus, aperiam, labore quia provident temporibus quasi est ut aliquid blanditiis beatae suscipit odio vel! Nostrum porro sunt sint eveniet maiores, dolorem itaque!'
		},
		{
			id: '3',
			title: 'Apple iPhone X',
			description:
				'Expedita sequi perferendis quod illum pariatur aliquam, alias laboriosam! Vero blanditiis placeat, mollitia necessitatibus reprehenderit. Labore dolores amet quos, accusamus earum asperiores officiis assumenda optio architecto quia neque, quae eum.'
		}
	]
});

export const addProduct = (product: Product) => {
	productState.products = [...productState.products, product];
};

export const deleteProduct = (productId: Product['id']) => {
	productState.products = productState.products.filter((p) => p.id !== productId);
};
