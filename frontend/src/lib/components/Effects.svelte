<script lang="ts">
	import { spring } from 'svelte/motion';
	import { themeState, getCursorColors, getAccentColor } from '$lib/stores/theme.svelte';
	import { onMount } from 'svelte';

	let coords = spring({ x: -100, y: -100 }, { stiffness: 0.1, damping: 0.25 });
	let trail = spring({ x: -100, y: -100 }, { stiffness: 0.05, damping: 0.3 });

	let cursorColors = $derived(getCursorColors());
	let effectsEnabled = $derived(themeState.mounted && themeState.effects);
	let accentColor = $derived(getAccentColor());
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
	let lastTouchCoords = { x: 0, y: 0 };
	let activeTimeouts: ReturnType<typeof setTimeout>[] = [];

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

	function handleTouchStart(e: TouchEvent) {
		if (!showEffects || e.touches.length === 0) return;
		const touch = e.touches[0];
		lastTouchCoords = { x: touch.clientX, y: touch.clientY };
	}

	function spawnParticles(x: number, y: number) {
		const particleCount = 8;
		const angleStep = (2 * Math.PI) / particleCount;
		const distance = 60;

		const newParticleIds: number[] = [];
		const newParticles: Particle[] = [];
		for (let i = 0; i < particleCount; i++) {
			const angle = i * angleStep + (Math.random() * 0.3);
			const dist = distance + (Math.random() * 20);
			const particle: Particle = {
				id: nextParticleId++,
				x,
				y,
				endX: Math.cos(angle) * dist,
				endY: Math.sin(angle) * dist
			};
			newParticleIds.push(particle.id);
			newParticles.push(particle);
		}

		particles = [...particles, ...newParticles];

		const idSet = new Set(newParticleIds);
		const timeoutId = setTimeout(() => {
			particles = particles.filter(p => !idSet.has(p.id));
		}, 400);
		activeTimeouts.push(timeoutId);
	}

	function onPointerDown(e: PointerEvent) {
		if (!showEffects) return;
		spawnParticles(e.clientX, e.clientY);
	}

	function onTouchEnd(e: TouchEvent) {
		if (!showEffects) return;
		if (e.changedTouches.length > 0) {
			const touch = e.changedTouches[0];
			spawnParticles(touch.clientX, touch.clientY);
		} else if (lastTouchCoords.x > 0 || lastTouchCoords.y > 0) {
			spawnParticles(lastTouchCoords.x, lastTouchCoords.y);
			lastTouchCoords = { x: 0, y: 0 };
		}
	}

	onMount(() => {
		window.addEventListener('mousemove', handleMouseMove);
		window.addEventListener('touchmove', handleTouchMove);
		window.addEventListener('touchstart', handleTouchStart, { passive: true });
		window.addEventListener('pointerdown', onPointerDown);
		window.addEventListener('touchend', onTouchEnd);

		return () => {
			window.removeEventListener('mousemove', handleMouseMove);
			window.removeEventListener('touchmove', handleTouchMove);
			window.removeEventListener('touchstart', handleTouchStart);
			window.removeEventListener('pointerdown', onPointerDown);
			window.removeEventListener('touchend', onTouchEnd);
			activeTimeouts.forEach(id => clearTimeout(id));
			activeTimeouts = [];
		};
	});
</script>

{#if showEffects}
	<div
		class="pointer-events-none fixed rounded-full"
		style="transform: translate({$coords.x}px, {$coords.y}px); background: {cursorColors.primary}; width: 12px; height: 12px; z-index: 300;"
	></div>
	<div
		class="pointer-events-none fixed rounded-full"
		style="transform: translate({$trail.x - 16}px, {$trail.y - 16}px); background: {cursorColors.trail}; filter: blur(12px); width: 32px; height: 32px; z-index: 299;"
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
