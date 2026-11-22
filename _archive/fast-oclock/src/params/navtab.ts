import type { ParamMatcher } from '@sveltejs/kit';
import type { NavTabType } from '$lib/types';

export const match = ((param: string): param is NavTabType => {
	return param === 'fasting' || param === 'timeline' || param === 'you';
}) satisfies ParamMatcher;
