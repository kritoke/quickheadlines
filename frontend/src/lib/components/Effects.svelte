<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState, getCursorColors, getThemeAccentColors } from '$lib/stores/theme.svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	let cursorColors = $derived(getCursorColors(themeState.theme));
	let enabled = $derived(themeState.mounted && themeState.effects);
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
		if (!enabled) return;
		coords.set({ x: e.clientX, y: e.clientY });
		setTimeout(() => trail.set({ x: e.clientX, y: e.clientY }), 50);
	}

	function handleTouchMove(e: TouchEvent) {
		if (!enabled || e.touches.length === 0) return;
		const touch = e.touches[0];
		coords.set({ x: touch.clientX, y: touch.clientY });
		setTimeout(() => trail.set({ x: touch.clientX, y: touch.clientY }), 50);
	}

	function handleClick(e: MouseEvent) {
		if (!enabled) return;
		spawnParticles(e.clientX, e.clientY);
	}

	function spawnParticles(x: number, y: number) {
		const particleCount = 6;
		const angleStep = (2 * Math.PI) / particleCount;
		const distance = 40;

		const newParticles: Particle[] = [];
		for (let i = 0; i < particleCount; i++) {
			const angle = i * angleStep;
			const endX = x + Math.cos(angle) * distance;
			const endY = y + Math.sin(angle) * distance;
			
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
		}, 450);
	}
</script>

<svelte:window 
	onmousemove={handleMouseMove} 
	ontouchmove={handleTouchMove}
	onclick={handleClick}
/>

{#if enabled}
	<div
		class="pointer-events-none fixed z-[9999999] w-3 h-3 rounded-full"
		style="left: {$coords.x}px; top: {$coords.y}px; background: {cursorColors.primary};"
	></div>
	<div
		class="pointer-events-none fixed z-[9999998] w-8 h-8 rounded-full"
		style="left: {$trail.x - 16}px; top: {$trail.y - 16}px; background: {cursorColors.trail}; filter: blur(12px);"
	></div>

	{#each particles as particle (particle.id)}
		{@const progress = 1 - particle.opacity}
		{@const currentX = particle.x + (particle.endX - particle.x) * progress}
		{@const currentY = particle.y + (particle.endY - particle.y) * progress}
		<div
			class="pointer-events-none fixed rounded-full"
			style="
				left: {currentX}px; 
				top: {currentY}px; 
				width: 4px; 
				height: 4px; 
				background: {accentColor};
				opacity: {particle.opacity};
				transform: translate(-50%, -50%);
				transition: opacity 0.4s ease-out;
			"
		></div>
	{/each}
{/if}
