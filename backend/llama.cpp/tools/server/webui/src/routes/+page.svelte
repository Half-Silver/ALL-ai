<script lang="ts">
	import { ChatScreen } from '$lib/components/app';
	import { chatStore, isInitialized } from '$lib/stores/chat.svelte';
	import { onMount } from 'svelte';

	onMount(async () => {
		if (!isInitialized) {
			await chatStore.initialize();
		}

		chatStore.clearActiveConversation();
	});
</script>

<svelte:head>
	<title>ALL ai - AI Chat Interface</title>
</svelte:head>

<ChatScreen showCenteredEmpty={true} />
