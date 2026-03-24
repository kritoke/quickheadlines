// Theme initialization logic extracted from app.html
// This module handles initial theme setup before Svelte hydration

export function initThemeFromHtml() {
  if (typeof document === 'undefined') return;
  
  const darkThemes = ['dark', 'retro', 'matrix', 'ocean', 'hotdog', 'dracula', 'cyberpunk', 'forest'];
  const themes = {
    light: {
      bg: '#ffffff', bgSecondary: '#f1f5f9', text: '#0f172a',
      border: '#e2e8f0', accent: '#3b82f6', shadow: 'rgba(59, 130, 246, 0.15)'
    },
    dark: {
      bg: '#1e293b', bgSecondary: '#0f172a', text: '#f1f5f9',
      border: '#334155', accent: '#60a5fa', shadow: 'rgba(96, 165, 250, 0.2)'
    },
    retro: {
      bg: '#1a1a2e', bgSecondary: '#0d0d1a', text: '#f1f5f9',
      border: '#ff71ce', accent: '#00d4ff', shadow: 'rgba(255, 113, 206, 0.3)'
    },
    matrix: {
      bg: '#000a00', bgSecondary: '#001a00', text: '#22c55e',
      border: '#166534', accent: '#00ff00', shadow: 'rgba(0, 255, 0, 0.3)'
    },
    ocean: {
      bg: '#2e3440', bgSecondary: '#242933', text: '#88c0d0',
      border: '#5e81ac', accent: '#88c0d0', shadow: 'rgba(136, 192, 208, 0.25)'
    },
    sunset: {
      bg: '#1c1309', bgSecondary: '#0e0904', text: '#fed7aa',
      border: '#f97316', accent: '#f97316', shadow: 'rgba(249, 115, 22, 0.25)'
    },
    hotdog: {
      bg: '#008080', bgSecondary: '#006666', text: '#fff59d',
      border: '#ff0000', accent: '#ff0000', shadow: 'rgba(255, 0, 0, 0.3)'
    },
    dracula: {
      bg: '#282a36', bgSecondary: '#1d1e26', text: '#f8f8f2',
      border: '#44475a', accent: '#bd93f9', shadow: 'rgba(189, 147, 249, 0.3)'
    },
    cyberpunk: {
      bg: '#0d0221', bgSecondary: '#060115', text: '#00ffff',
      border: '#ff00ff', accent: '#ff00ff', shadow: 'rgba(255, 0, 255, 0.3)'
    },
    forest: {
      bg: '#1a2e1a', bgSecondary: '#0f1a0f', text: '#d1fae5',
      border: '#166534', accent: '#4ade80', shadow: 'rgba(74, 222, 128, 0.25)'
    }
  };

  const validThemes = Object.keys(themes);

  function applyTheme(theme: string) {
    const t = themes[theme as keyof typeof themes];
    if (!t) return;
    document.documentElement.style.setProperty('--theme-bg', t.bg);
    document.documentElement.style.setProperty('--theme-text', t.text);
    document.documentElement.style.setProperty('--theme-border', t.border);
    document.documentElement.style.setProperty('--theme-accent', t.accent);
    document.documentElement.style.setProperty('--theme-shadow', t.shadow);
    document.documentElement.setAttribute('data-theme', theme);
    document.documentElement.classList.toggle('dark', darkThemes.includes(theme));
  }

  let theme = 'light';
  try {
    theme = localStorage.getItem('quickheadlines-theme') || 'light';
  } catch (e) {}

  if (!validThemes.includes(theme)) {
    theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  applyTheme(theme);
}