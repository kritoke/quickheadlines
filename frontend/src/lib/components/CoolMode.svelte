<script lang="ts">
	import { onDestroy } from 'svelte';
	import type { Snippet } from 'svelte';

	export interface CoolParticleOptions {
		particle?: string;
		particleCount?: number;
		size?: number;
		speedHorz?: number;
		speedUp?: number;
	}

	interface CoolParticle {
		element: HTMLElement;
		left: number;
		size: number;
		top: number;
		direction: number;
		speedHorz: number;
		speedUp: number;
		spinSpeed: number;
		spinVal: number;
	}

	interface CoolModeProps {
		children: Snippet;
		options?: CoolParticleOptions;
		enabled?: boolean;
	}

	let { children, options, enabled = true }: CoolModeProps = $props();

	let ref: HTMLSpanElement;
	let cleanup: (() => void) | undefined;

	const getContainer = () => {
		const id = '_coolMode_effect';
		const existingContainer = document.getElementById(id);

		if (existingContainer) {
			return existingContainer;
		}

		const container = document.createElement('div');
		container.setAttribute('id', id);
		container.setAttribute(
			'style',
			'overflow:hidden; position:fixed; height:100%; top:0; left:0; right:0; bottom:0; pointer-events:none; z-index:2147483647'
		);

		document.body.appendChild(container);

		return container;
	};

	const applyParticleEffect = (
		element: HTMLElement,
		opts?: CoolParticleOptions
	): (() => void) => {
		const defaultParticle = 'circle';
		const particleType = opts?.particle || defaultParticle;
		const sizes = [15, 20, 25, 35, 45];
		const limit = 45;

		let particles: CoolParticle[] = [];
		let autoAddParticle = false;
		let mouseX = 0;
		let mouseY = 0;
		let animationFrame: number | undefined;
		let instanceActive = true;

		const container = getContainer();

		function generateParticle() {
			const size = opts?.size || sizes[Math.floor(Math.random() * sizes.length)];
			const speedHorz = opts?.speedHorz || Math.random() * 10;
			const speedUp = opts?.speedUp || Math.random() * 25;
			const spinVal = Math.random() * 360;
			const spinSpeed = Math.random() * 35 * (Math.random() <= 0.5 ? -1 : 1);
			const top = mouseY - size / 2;
			const left = mouseX - size / 2;
			const direction = Math.random() <= 0.5 ? -1 : 1;

			const particle = document.createElement('div');

			if (particleType === 'circle') {
				const svgNS = 'http://www.w3.org/2000/svg';
				const circleSVG = document.createElementNS(svgNS, 'svg');
				const circle = document.createElementNS(svgNS, 'circle');
				circle.setAttributeNS(null, 'cx', (size / 2).toString());
				circle.setAttributeNS(null, 'cy', (size / 2).toString());
				circle.setAttributeNS(null, 'r', (size / 2).toString());
				circle.setAttributeNS(null, 'fill', `hsl(${Math.random() * 360}, 70%, 50%)`);

				circleSVG.appendChild(circle);
				circleSVG.setAttribute('width', size.toString());
				circleSVG.setAttribute('height', size.toString());

				particle.appendChild(circleSVG);
			} else if (particleType.startsWith('http') || particleType.startsWith('/')) {
				const img = document.createElement('img');
				img.src = particleType;
				img.width = size;
				img.height = size;
				img.style.borderRadius = '50%';
				particle.appendChild(img);
			} else {
				const fontSizeMultiplier = 3;
				const emojiSize = size * fontSizeMultiplier;
				const div = document.createElement('div');
				div.style.fontSize = `${emojiSize}px`;
				div.style.lineHeight = '1';
				div.style.textAlign = 'center';
				div.style.width = `${size}px`;
				div.style.height = `${size}px`;
				div.style.display = 'flex';
				div.style.alignItems = 'center';
				div.style.justifyContent = 'center';
				div.style.transform = `scale(${fontSizeMultiplier})`;
				div.style.transformOrigin = 'center';
				div.textContent = particleType;
				particle.appendChild(div);
			}

			particle.style.position = 'absolute';
			particle.style.transform = `translate3d(${left}px, ${top}px, 0px) rotate(${spinVal}deg)`;

			container.appendChild(particle);

			particles.push({
				direction,
				element: particle,
				left,
				size,
				speedHorz,
				speedUp,
				spinSpeed,
				spinVal,
				top
			});
		}

		function refreshParticles() {
			particles.forEach((p) => {
				p.left = p.left - p.speedHorz * p.direction;
				p.top = p.top - p.speedUp;
				p.speedUp = Math.min(p.size, p.speedUp - 1);
				p.spinVal = p.spinVal + p.spinSpeed;

				if (p.top >= Math.max(window.innerHeight, document.body.clientHeight) + p.size) {
					particles = particles.filter((o) => o !== p);
					p.element.remove();
				}

				p.element.setAttribute(
					'style',
					[
						'position:absolute',
						'will-change:transform',
						`top:${p.top}px`,
						`left:${p.left}px`,
						`transform:rotate(${p.spinVal}deg)`
					].join(';')
				);
			});
		}

		let lastParticleTimestamp = 0;
		const particleGenerationDelay = 30;

		function loop() {
			if (!instanceActive) return;
			
			const currentTime = performance.now();
			if (
				autoAddParticle &&
				particles.length < limit &&
				currentTime - lastParticleTimestamp > particleGenerationDelay
			) {
				generateParticle();
				lastParticleTimestamp = currentTime;
			}

			refreshParticles();
			animationFrame = requestAnimationFrame(loop);
		}

		loop();

		const isTouchInteraction = 'ontouchstart' in window;

		const tap = isTouchInteraction ? 'touchstart' : 'mousedown';
		const tapEnd = isTouchInteraction ? 'touchend' : 'mouseup';
		const move = isTouchInteraction ? 'touchmove' : 'mousemove';

		const updateMousePosition = (e: MouseEvent | TouchEvent) => {
			if ('touches' in e) {
				mouseX = e.touches?.[0].clientX;
				mouseY = e.touches?.[0].clientY;
			} else {
				mouseX = e.clientX;
				mouseY = e.clientY;
			}
		};

		const tapHandler = (e: MouseEvent | TouchEvent) => {
			updateMousePosition(e);
			autoAddParticle = true;
		};

		const disableAutoAddParticle = () => {
			autoAddParticle = false;
		};

		element.addEventListener(move, updateMousePosition, { passive: true });
		element.addEventListener(tap, tapHandler, { passive: true });
		element.addEventListener(tapEnd, disableAutoAddParticle, { passive: true });
		element.addEventListener('mouseleave', disableAutoAddParticle, {
			passive: true
		});

		return () => {
			instanceActive = false;
			element.removeEventListener(move, updateMousePosition);
			element.removeEventListener(tap, tapHandler);
			element.removeEventListener(tapEnd, disableAutoAddParticle);
			element.removeEventListener('mouseleave', disableAutoAddParticle);

			if (animationFrame) {
				cancelAnimationFrame(animationFrame);
			}

			particles.forEach(p => p.element.remove());
			particles = [];
			
			const checkContainer = setInterval(() => {
				if (particles.length === 0) {
					clearInterval(checkContainer);
					const c = document.getElementById('_coolMode_effect');
					if (c && c.childElementCount === 0) {
						c.remove();
					}
				}
			}, 100);
		};
	};

	$effect(() => {
		if (enabled && ref) {
			cleanup?.();
			cleanup = applyParticleEffect(ref, options);
		} else if (!enabled && cleanup) {
			cleanup();
			cleanup = undefined;
		}
	});

	onDestroy(() => {
		cleanup?.();
	});
</script>

<span bind:this={ref}>
	{@render children()}
</span>
