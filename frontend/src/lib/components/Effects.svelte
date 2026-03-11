<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState, getCursorColors, getThemeAccentColors } from '$lib/stores/theme.svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	let cursorColors = $derived(getCursorColors(themeState.theme));
	let effectsEnabled = $derived(themeState.mounted && themeState.effects);
	let accentColor = $derived(getThemeAccentColors(themeState.theme).accent);

	interface Particle {
		id: number;
		x: number;
		y: number;
		endX: number;
		endY: number;
		opacity: number;
	}

	let particles = $state<Particle[]>([]);
	let nextParticleId = 0;

	function handleMouseMove(e: MouseEvent) {
		if (!effectsEnabled) return;
		coords.set({ x: e.clientX, y: e.clientY });
		setTimeout(() => trail.set({ x: e.clientX, y: e.clientY }), 50);
	}

	function handleTouchMove(e: TouchEvent) {
		if (!effectsEnabled || e.touches.length === 0) return;
		const touch = e.touches[0];
		coords.set({ x: touch.clientX, y: touch.clientY });
		setTimeout(() => trail.set({ x: touch.clientX, y: touch.clientY }), 50);
	}

	function handleClick(e: MouseEvent) {
		spawnParticles(e.clientX, e.clientY);
	}

	function spawnParticles(x: number, y: number) {
		const particleCount = 8;
		const angleStep = (2 * Math.PI) / particleCount;
		const distance = 60;

		const newParticles: Particle[] = [];
		for (let i = 0; i < particleCount; i++) {
			const angle = i * angleStep + (Math.random() * 0.3);
			const dist = distance + (Math.random() * 20);
			const endX = x + Math.cos(angle) * dist;
			const endY = y + Math.sin(angle) * dist;
			
			const particle: Particle = {
				id: nextParticleId++,
				x,
				y,
				endX,
				endY,
				opacity: 1
			};
			newParticles.push(particle);
		}

		particles = [...particles, ...newParticles];

		setTimeout(() => {
			particles = particles.map(p => {
				if (newParticles.find(np => np.id === p.id)) {
					return { ...p, opacity: 0 };
				}
				return p;
			});
		}, 50);

		setTimeout(() => {
			particles = particles.filter(p => !newParticles.find(np => np.id === p.id));
		}, 500);
	}
</script>

<svelte:window 
	onmousemove={handleMouseMove} 
	ontouchmove={handleTouchMove}
	onclick={handleClick}
/>

{#if effectsEnabled}
	<div
		class="pointer-events-none fixed z-[9999999] w-3 h-3 rounded-full"
		style="left: {$coords.x}px; top: {$coords.y}px; background: {cursorColors.primary};"
	></div>
	<div
		class="pointer-events-none fixed z-[9999998] w-8 h-8 rounded-full"
		style="left: {$trail.x - 16}px; top: {$trail.y - 16}px; background: {cursorColors.trail}; filter: blur(12px);"
	></div>
{/if}

{#each particles as particle (particle.id)}
	<div
		class="pointer-events-none fixed rounded-full particle-burst"
		style="
			left: {particle.x}px; 
			top: {particle.y}px; 
			width: 6px; 
			height: 6px; 
			background: {accentColor};
			opacity: {particle.opacity};
			transform: translate(-50%, -50%);
		"
	></div>
{/each}

<style>
	.particle-burst {
		transition: left 0.4s ease-out, top 0.4s ease-out, opacity 0.4s ease-out;
	}
</style>
