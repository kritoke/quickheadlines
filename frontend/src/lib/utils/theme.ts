const BEAM_THEMES = ['cyberpunk', 'matrix', 'dracula', 'ocean', 'vaporwave', 'retro80s'] as const;
export type BeamTheme = typeof BEAM_THEMES[number];

export const BEAM_COLORS: Record<BeamTheme, { from: string; to: string; via?: string }> = {
	matrix: { from: '#00ff00', to: '#22c55e' },
	cyberpunk: { from: '#ff00ff', to: '#00ffff' },
	vaporwave: { from: '#ff71ce', to: '#b967ff', via: '#01cdfe' },
	retro80s: { from: '#ff2e63', to: '#00d4ff' },
	dracula: { from: '#bd93f9', to: '#50fa7b', via: '#ff79c6' },
	ocean: { from: '#06b6d4', to: '#0ea5e9', via: '#22d3ee' }
};

const DEFAULT_BEAM_COLORS = { from: '#ff00ff', to: '#00ffff' };

let cachedIsIOS: boolean | null = null;

export function isIOS(): boolean {
	if (cachedIsIOS !== null) return cachedIsIOS;
	cachedIsIOS = typeof navigator !== 'undefined' && /iPad|iPhone|iPod/.test(navigator.userAgent);
	return cachedIsIOS;
}

export function shouldShowBorderBeam(theme: string): boolean {
	return !isIOS() && (theme in BEAM_COLORS);
}

export function getBeamColors(theme: string): { from: string; to: string; via?: string } {
	return BEAM_COLORS[theme as BeamTheme] ?? DEFAULT_BEAM_COLORS;
}