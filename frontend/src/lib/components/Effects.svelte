<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState, getCursorColors, getThemeAccentColors } from '$lib/stores/theme.svelte';
	import { zIndex } from '$lib/design/tokens';
	import { onMount } from 'svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	let cursorColors = $derived(getCursorColors(themeState.theme));
	let effectsEnabled = $derived(themeState.mounted && themeState.effects);
	let accentColor = $derived(getThemeAccentColors(themeState.theme).accent);
	let reducedMotion = $state(false);

	$effect(() => {
		if (typeof window === 'undefined') return;
		reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
	});

	let showEffects = $derived(effectsEnabled && !reducedMotion);

	interface Particle {
		id: number;
		x: number;
		y: number;
		endX: number;
		endY: number;
	}

	let particles = $state<Particle[]>([]);
	let nextParticleId = 0;

	function handleMouseMove(e: MouseEvent) {
		if (!showEffects) return;
		coords.set({ x: e.clientX, y: e.clientY });
		setTimeout(() => trail.set({ x: e.clientX, y: e.clientY }), 50);
	}

	function handleTouchMove(e: TouchEvent) {
		if (!showEffects || e.touches.length === 0) return;
		const touch = e.touches[0];
		coords.set({ x: touch.clientX, y: touch.clientY });
		setTimeout(() => trail.set({ x: touch.clientX, y: touch.clientY }), 50);
	}

	function spawnParticles(x: number, y: number) {
		const particleCount = 8;
		const angleStep = (2 * Math.PI) / particleCount;
		const distance = 60;

		const newParticles: Particle[] = [];
		for (let i = 0; i < particleCount; i++) {
			const angle = i * angleStep + (Math.random() * 0.3);
			const dist = distance + (Math.random() * 20);
			const endX = Math.cos(angle) * dist;
			const endY = Math.sin(angle) * dist;
			
			const particle: Particle = {
				id: nextParticleId++,
				x,
				y,
				endX,
				endY
			};
			newParticles.push(particle);
		}

		particles = [...particles, ...newParticles];

		setTimeout(() => {
			particles = particles.filter(p => !newParticles.find(np => np.id === p.id));
		}, 400);
	}

	function onPointerDown(e: PointerEvent) {
		if (!showEffects) return;
		spawnParticles(e.clientX, e.clientY);
	}

	onMount(() => {
		window.addEventListener('mousemove', handleMouseMove);
		window.addEventListener('touchmove', handleTouchMove, { passive: true });
		window.addEventListener('pointerdown', onPointerDown);

		return () => {
			window.removeEventListener('mousemove', handleMouseMove);
			window.removeEventListener('touchmove', handleTouchMove);
			window.removeEventListener('pointerdown', onPointerDown);
		};
	});
</script>

{#if showEffects}
	<div
		class="pointer-events-none fixed rounded-full"
		style="transform: translate({$coords.x}px, {$coords.y}px); background: {cursorColors.primary}; width: 12px; height: 12px; z-index: {zIndex.effects};"
	></div>
	<div
		class="pointer-events-none fixed rounded-full"
		style="transform: translate({$trail.x - 16}px, {$trail.y - 16}px); background: {cursorColors.trail}; filter: blur(12px); width: 32px; height: 32px; z-index: {zIndex.effects - 1};"
	></div>

	{#each particles as particle (particle.id)}
		<div
			class="particle-burst pointer-events-none fixed rounded-full"
			style="
				--end-x: {particle.endX}px;
				--end-y: {particle.endY}px;
				left: {particle.x}px; 
				top: {particle.y}px; 
				width: 8px; 
				height: 8px; 
				background: {accentColor};
			"
		></div>
	{/each}
{/if}

<style>
	.particle-burst {
		animation: burst 0.4s ease-out forwards;
	}

	@keyframes burst {
		0% {
			transform: translate(-50%, -50%) scale(1);
			opacity: 1;
		}
		100% {
			transform: translate(calc(-50% + var(--end-x)), calc(-50% + var(--end-y))) scale(0.5);
			opacity: 0;
		}
	}
</style>
