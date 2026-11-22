// theme: 'white' | 'g10' | 'g80' | 'g90' | 'g100'
type UserData = {
	isOnboarded?: boolean;
};
export const userDataStore = $state<UserData>({
	// TODO: set defaults somewhere
	isOnboarded: false
});
