import { redirect } from '@sveltejs/kit';
import { DEFAULT_TAB } from '$lib/types';

export function load() {
	throw redirect(307, `/home/${DEFAULT_TAB}`);
}
