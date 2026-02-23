<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';
  import { CrystalEngine } from '$lib/crystal-engine';
  import { themeState } from '$lib/stores/theme.svelte';

  let canvasEl = $state<HTMLCanvasElement | null>(null);
  let engine = $state<CrystalEngine | null>(null);
  let mounted = $state(false);

  onMount(() => {
    if (!browser) return;
    
    mounted = true;
    
    requestAnimationFrame(() => {
      if (canvasEl) {
        engine = new CrystalEngine(canvasEl, {
          width: 60,
          height: 60,
        });
        engine.setDarkMode(themeState.theme === 'dark');
      }
    });
  });

  onDestroy(() => {
    engine?.destroy();
  });

  $effect(() => {
    if (engine && browser) {
      engine.setDarkMode(themeState.theme === 'dark');
    }
  });
</script>

{#if mounted}
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
    class="text-xs text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 transition-colors"
  >
    Powered by Crystal
  </a>
</div>
{/if}
