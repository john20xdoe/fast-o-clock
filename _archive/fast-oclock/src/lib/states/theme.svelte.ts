export type ThemeVal = 'white' | 'g10' | 'g80' | 'g90' | 'g100';
type ThemeValue = { theme?: ThemeVal };

export const themes: ThemeVal[] = ['white', 'g10', 'g80', 'g90', 'g100'] as const;

export const initialTheme = themes[4];
export const themeStore = $state<ThemeValue>({
	theme: initialTheme
});
