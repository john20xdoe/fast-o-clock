# sv

Everything you need to build a Svelte project, powered by [`sv`](https://github.com/sveltejs/cli).

## Node prerequisites

- Volta.sh
- npm install -g corepack
- corepack enable --install-directory ~/.volta/bin
- yarn set version stable
- yarn

## Creating a project

If you're seeing this, you've probably already done this step. Congrats!

```bash
# create a new project in the current directory
npx sv create

# create a new project in my-app
npx sv create my-app
```

## Developing

Once you've created a project and installed dependencies with `npm install` (or `pnpm install` or `yarn`), start a development server:

```bash
yarn dev

# or start the server and open the app in a new browser tab
yarn dev -- --open
```

### With Live-reload on simulators

```bash
NODE_ENV=dev yarn live:ios
NODE_ENV=dev yarn live:android
```

Make sure to click Run on the Workspace (XCode or Android Studio) that opens so that the app will run on the simulator. Any live edits on the files will now reflect in this instance of the app.

## With physical device

First connect your iOS/Android device by USB cable. Android Studio requires USB debugging to be enabled on your device via Developer Options.

```bash
NODE_ENV=dev yarn ios
NODE_ENV=dev yarn android
```

## Building

To create a production version of your app:

```bash
yarn build
```

You can preview the production build with `yarn preview`.

> To deploy your app, you may need to install an [adapter](https://svelte.dev/docs/kit/adapters) for your target environment.

## Capacitor Deployment

### iOS

1. brew install rbenv
2. rbenv init # sets `rbenv init` to .zprofile. But check step 4.
3. rbenv install 3.4.2 #latest stable
4. rbenv local 3.4.2 # also check your .zshrc contains `eval "$(rbenv init -)"`, add it if ruby -v not changing to 3.4.2
