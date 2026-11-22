import type { CapacitorConfig } from '@capacitor/cli';

import { Env } from './src/lib/env.enum';
import { AppMeta } from './src/lib/app.enum';

const isDevelopment = process.env.NODE_ENV === Env.dev;

const localhostInstance = 'http://localhost:5173';

const baseConfig: CapacitorConfig = {
	appId: AppMeta.appId,
	appName: AppMeta.appName,
	zoomEnabled: false,
	ios: {
		preferredContentMode: 'mobile'
	},
	android: {},
	webDir: 'www',
	plugins: {
		SplashScreen: {
			launchShowDuration: 0
		}
	},
	cordova: {}
};

const localLiveReloadServer = {
	// Server is only enabled during development
	...(isDevelopment && {
		server: {
			url: localhostInstance,
			cleartext: true,
			androidScheme: 'http'
		}
	})
};

let config: CapacitorConfig;
const ENV = process.env.NODE_ENV ?? Env.dev;

switch (ENV) {
	case Env.prod:
		config = {
			...baseConfig,
			appId: `${baseConfig.appId}`,
			ios: {
				...baseConfig.ios,
				scheme: 'App'
			},
			android: {
				...baseConfig.android,
				flavor: 'prod'
			}
		};
		break;
	case Env.qa:
		config = {
			...baseConfig,
			appId: `${baseConfig.appId}_qa`,
			ios: {
				...baseConfig.ios,
				scheme: 'App QA',
				buildOptions: {
					signingStyle: 'automatic'
				}
			},
			android: {
				...baseConfig.android,
				flavor: 'qa'
			}
		};
		break;
	case Env.dev:
		config = {
			...baseConfig,
			...localLiveReloadServer,
			appId: `${baseConfig.appId}_dev`,
			ios: {
				...baseConfig.ios,
				scheme: 'App Dev',
				loggingBehavior: 'debug'
			},
			android: {
				...baseConfig.android,
				flavor: 'dev',
				loggingBehavior: 'debug'
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
