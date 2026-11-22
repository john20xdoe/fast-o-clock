import type { Capacitor } from '@capacitor/core';

/** Ref: https://capacitorjs.com/docs/core-apis/web#capacitor-object */
declare global {
	interface Window {
		Capacitor: Capacitor;
	}
}
