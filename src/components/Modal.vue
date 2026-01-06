<script setup lang="ts">
import { X } from 'lucide-vue-next'

defineProps<{
  show: boolean
  title: string
  size?: 'sm' | 'md' | 'lg'
}>()

const emit = defineEmits<{
  close: []
}>()
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="show" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div
          class="absolute inset-0 bg-foreground/40 backdrop-blur-sm"
          @click="emit('close')"
        />

        <!-- Modal -->
        <Transition name="modal-content" appear>
          <div
            :class="[
              'relative bg-card border rounded-2xl shadow-2xl shadow-black/10 w-full',
              size === 'sm' ? 'max-w-sm' : size === 'lg' ? 'max-w-2xl' : 'max-w-md'
            ]"
          >
            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b">
              <h2 class="text-lg font-semibold text-foreground tracking-tight">{{ title }}</h2>
              <button
                @click="emit('close')"
                class="p-2 -mr-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-xl transition-all active:scale-95"
              >
                <X class="w-5 h-5" />
              </button>
            </div>

            <!-- Content -->
            <div class="px-6 py-5">
              <slot />
            </div>

            <!-- Footer -->
            <div v-if="$slots.footer" class="flex items-center justify-end gap-2 px-6 py-4 border-t bg-muted/30 rounded-b-2xl">
              <slot name="footer" />
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-content-enter-active {
  transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.modal-content-leave-active {
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

.modal-content-enter-from {
  opacity: 0;
  transform: scale(0.95) translateY(10px);
}

.modal-content-leave-to {
  opacity: 0;
  transform: scale(0.98);
}
</style>
