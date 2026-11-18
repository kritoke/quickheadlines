<script lang="ts">
  import { browser } from '$app/env';
  import { CrystalEngine } from '#lib/crystal-engine';
  import { themeState, isDarkTheme } from '#lib/stores/theme.svelte';

  let canvasEl = $state<HTMLCanvasElement | null>(null);
  let engine = $state<CrystalEngine | null>(null);

  $effect(() => {
    if (!browser) return;
    
    // Cleanup previous engine if exists
    engine?.destroy();
    
    // Initialize engine when canvas is available
    if (canvasEl) {
      engine = new CrystalEngine(canvasEl, {
        width: 60,
        height: 60,
      });
      engine.setDarkMode(isDarkTheme());
    }
    
    // Cleanup function for when canvasEl changes or component unmounts
    return () => {
      engine?.destroy();
    };
  });

  $effect(() => {
    // Read themeState.theme so this effect re-runs on theme changes;
    // isDarkTheme() itself reads the DOM and isn't tracked.
    const _theme = themeState.theme;
    if (engine && browser) {
      engine.setDarkMode(isDarkTheme());
    }
  });
</script>

{#if canvasEl}
<div class="flex items-center gap-2 select-none">
  <canvas
    bind:this={canvasEl}
    width="60"
    height="60"
    class="cursor-grab active:cursor-grabbing"
  ></canvas>
  <a
    href="https://crystal-lang.org/"
    target="_blank"
    rel="noopener noreferrer"
    class="text-xs text-surface-500 dark:text-surface-400 hover:text-slate-700 dark:hover:text-slate-300 transition-colors"
  >
    Powered by Crystal
  </a>
</div>
{/if}