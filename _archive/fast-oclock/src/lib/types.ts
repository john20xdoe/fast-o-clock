import type { Component } from 'svelte';

export type NavTabItem<TValue = number> = {
	icon: Component;
	value: TValue;
	text: string;
	href: string;
	description?: string;
	// active: boolean;
};

export type NavTabType = 'fasting' | 'timeline' | 'you';

export const DEFAULT_TAB = 'fasting';
