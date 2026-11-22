import type { Router } from 'framework7/types';
import type { User } from '../lib/stores/user.svelte';

import DynamicRoutePage from '../pages/dynamic-route.svelte';
import RequestAndLoad from '../pages/request-and-load.svelte';
import NotFoundPage from '../pages/404.svelte';

import HomePage from '../pages/home.svelte';
import AboutPage from '../pages/about.svelte';
import FormPage from '../pages/form.svelte';
import CatalogPage from '../pages/catalog.svelte';
import ProductPage from '../pages/product.svelte';
import SettingsPage from '../pages/settings.svelte';

const routes: Router.RouteParameters[] = [
	{
		path: '/',
		component: HomePage
	},
	{
		path: '/about/',
		component: AboutPage
	},
	{
		path: '/form/',
		component: FormPage
	},
	{
		path: '/catalog/',
		component: CatalogPage
	},
	{
		//   path: "/product/:id/",
		//   component: ProductPage,
		path: '/product/', // TODO: try this out later
		master: true,
		detailRoutes: [
			{
				path: '/product/:id/',
				component: ProductPage
			}
		]
	},
	{
		path: '/settings/',
		component: SettingsPage
	},

	{
		path: '/dynamic-route/blog/:blogId/post/:postId/',
		component: DynamicRoutePage
	},
	{
		path: '/request-and-load/user/:userId/',
		async: ({ router, to, resolve }) => {
			// App instance
			const app = router.app;

			// Show Preloader
			app.preloader.show();

			// User ID from request
			const userId = to.params.userId;

			// Simulate Ajax Request
			setTimeout(function () {
				// We got user data from request
				const user: User = {
					id: `${userId}`,
					firstName: 'John',
					lastName: 'Doe',
					about: 'Hello, I am a fasting beginner',
					links: [
						{
							title: 'Framework7 Website',
							url: 'http://framework7.io'
						}
					]
				};
				// Hide Preloader
				app.preloader.hide();

				// Resolve route to load page
				resolve(
					{
						component: RequestAndLoad
					},
					{
						props: {
							user: user
						}
					}
				);
			}, 1000);
		}
	},
	{
		path: '(.*)',
		component: NotFoundPage
	}
];

export default routes;
