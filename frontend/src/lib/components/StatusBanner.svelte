<script lang="ts">
	interface Props {
		message: string;
		tone?: 'primary' | 'amber';
		class?: string;
		textClass?: string;
	}

	let { message, tone = 'primary', class: className = '', textClass = '' }: Props = $props();
</script>

<div class={className}>
	<div
		class="w-4 h-4 border-2 {tone === 'amber'
			? 'border-amber-500'
			: 'border-primary-500'} border-t-transparent rounded-full animate-spin"
	></div>
	<span class={textClass}>{message}</span>
</div>
