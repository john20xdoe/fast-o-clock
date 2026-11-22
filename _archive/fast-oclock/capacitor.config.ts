import type { CapacitorConfig } from '@capacitor/cli';

import { Env } from './src/lib/env.enum';

const isDevelopment = process.env.NODE_ENV === Env.dev;

const localhostInstance = 'http://localhost:5173';

const baseConfig: CapacitorConfig = {
	appId: 'com.neurral.fastoclock_v0',
	appName: 'Fast-OClock',
	webDir: 'dist',
	android: {
		adjustMarginsForEdgeToEdge: 'auto'
	}
};

const localLiveReloadServer = {
	// Server is only enabled during development
	...(isDevelopment && {
		server: {
			url: localhostInstance,
			cleartext: true
		}
	})
};

let config: CapacitorConfig;

switch (process.env.NODE_ENV) {
	case Env.prod:
		config = {
			...baseConfig,
			ios: {
				scheme: 'App'
			},
			android: {
				flavor: 'prod'
			}
		};
		break;
	case Env.qa:
		config = {
			...baseConfig,
			ios: {
				scheme: 'App QA'
			},
			android: {
				flavor: 'qa'
			}
		};
		break;
	case Env.dev:
		config = {
			...baseConfig,
			...localLiveReloadServer,
			ios: {
				scheme: 'App Dev'
			},
			android: {
				flavor: 'dev'
			}
		};
		break;
	default:
		config = {
			...baseConfig
		};
		break;
}

export default config;
