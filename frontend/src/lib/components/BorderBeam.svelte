<script lang="ts">
	interface Props {
		colorFrom?: string;
		colorTo?: string;
		colorVia?: string;
		duration?: number;
		size?: number;
	}

	let {
		colorFrom = '#ff00ff',
		colorTo = '#00ffff',
		colorVia,
		duration = 5,
		size = 200
	}: Props = $props();

	let gradient = $derived.by(() => {
		if (colorVia) {
			return `conic-gradient(from 0deg, transparent 0%, ${colorFrom} 25%, ${colorVia} 50%, ${colorTo} 75%, transparent 100%)`;
		}
		return `conic-gradient(from 0deg, transparent 0%, ${colorFrom} 25%, ${colorTo} 50%, transparent 100%)`;
	});
</script>

<div
	class="border-beam-wrapper absolute -inset-px rounded-lg pointer-events-none overflow-hidden"
>
	<div
		class="border-beam-glow"
		style="background: {gradient}; animation-duration: {duration}s; width: {size}%; height: {size}%;"
	></div>
</div>

<style>
	.border-beam-wrapper {
		mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
		mask-composite: exclude;
		-webkit-mask-composite: exclude;
		-moz-mask-composite: exclude;
		padding: 2px;
		isolation: isolate;
		transform: translateZ(0);
		backface-visibility: hidden;
	}

	.border-beam-glow {
		position: absolute;
		inset: -50%;
		animation: border-beam-rotate linear infinite;
		filter: blur(0px);
		will-change: transform;
		transform: translateZ(0);
		backface-visibility: hidden;
	}

	@keyframes border-beam-rotate {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}
</style>
