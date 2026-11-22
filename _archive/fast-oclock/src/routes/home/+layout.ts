import type { LayoutLoad } from './$types';
import { Activity, FaceCool, UpdateNow } from 'carbon-icons-svelte';

import { HomePanels } from '$lib';
import { DEFAULT_TAB, type NavTabItem, type NavTabType } from '$lib/types';

type HomeParams = {
	slug?: NavTabType;
};

export const prerender = 'auto';

// We setup the tab metadata in server because we want to rely on the value of [slug] to set as active
const homeTabs: Record<NavTabType, NavTabItem<HomePanels>> = {
	fasting: {
		value: HomePanels.FASTING,
		icon: UpdateNow,
		text: 'Fasting',
		href: 'fasting',
		description: 'Track your current fast and see your progress'
		// active: true
	},
	timeline: {
		value: HomePanels.TIMELINE,
		icon: Activity,
		text: 'Timeline',
		href: 'timeline',
		description: 'View your fasting history and achievements'
		// active: false
	},
	you: {
		value: HomePanels.YOU,
		icon: FaceCool,
		text: 'You',
		href: 'you',
		description: 'Manage your personal settings and goals'
		// active: false
	}
};

export const load: LayoutLoad = ({ params }) => {
	// TODO: add a getData(user) here to preload database data
	const tabs = { ...homeTabs };
	const { slug = DEFAULT_TAB } = params as HomeParams;

	if (slug in homeTabs) {
		return { tabs: Object.values(tabs), activeTab: tabs[slug] };
	}

	return { tabs: Object.values(tabs), activeTab: tabs[DEFAULT_TAB] };
};
