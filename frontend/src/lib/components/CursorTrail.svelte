<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { themeState } from '$lib/stores/theme.svelte';

	let container: HTMLDivElement;
	let cleanup: (() => void) | undefined;

	const getContainer = () => {
		const id = '_cursorTrail_effect';
		const existingContainer = document.getElementById(id);

		if (existingContainer) {
			return existingContainer;
		}

		const div = document.createElement('div');
		div.setAttribute('id', id);
		div.setAttribute('style', 'overflow:hidden; position:fixed; height:100%; top:0; left:0; right:0; bottom:0; pointer-events:none; z-index:2147483647');

		document.body.appendChild(div);
		return div;
	};

	const createParticle = (x: number, y: number) => {
		const particle = document.createElement('div');
		const size = Math.random() * 20 + 15;
		particle.setAttribute('style', `
			position: absolute;
			width: ${size}px;
			height: ${size}px;
			border-radius: 50%;
			background: rgba(150, 173, 141, ${Math.random() * 0.3 + 0.2});
			left: ${x - size/2}px;
			top: ${y - size/2}px;
			pointer-events: none;
			animation: fadeOut 1s ease-out forwards;
		`);
		
		// Add animation keyframes if not exists
		if (!document.getElementById('_cursorTrail_animations')) {
			const style = document.createElement('style');
			style.id = '_cursorTrail_animations';
			style.textContent = `
				@keyframes fadeOut {
					0% { opacity: 1; transform: scale(1); }
					100% { opacity: 0; transform: scale(0.5); }
				}
			`;
			document.head.appendChild(style);
		}
		
		getContainer().appendChild(particle);
		
		setTimeout(() => particle.remove(), 1000);
	};

	const handleClick = (e: MouseEvent) => {
		if (!themeState.coolMode) return;
		for (let i = 0; i < 5; i++) {
			setTimeout(() => createParticle(e.clientX, e.clientY), i * 50);
		}
	};

	onMount(() => {
		document.addEventListener('click', handleClick);
		cleanup = () => document.removeEventListener('click', handleClick);
	});

	onDestroy(() => {
		if (cleanup) cleanup();
	});
</script>
