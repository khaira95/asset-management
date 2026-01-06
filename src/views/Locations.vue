<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Location } from '@/types/database'
import { MapPin, Plus, Pencil, Trash2 } from 'lucide-vue-next'
import Modal from '@/components/Modal.vue'

const locations = ref<Location[]>([])
const loading = ref(true)
const saving = ref(false)

// Modal state
const showModal = ref(false)
const editingId = ref<number | null>(null)
const form = ref({ name: '' })
const formError = ref('')

function openCreate() {
  editingId.value = null
  form.value = { name: '' }
  formError.value = ''
  showModal.value = true
}

function openEdit(location: Location) {
  editingId.value = location.id
  form.value = { name: location.name }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingId.value = null
  form.value = { name: '' }
  formError.value = ''
}

async function fetchLocations() {
  try {
    const { data, error } = await supabase
      .from('locations')
      .select('*')
      .order('name')

    if (error) throw error
    locations.value = data || []
  } catch (error) {
    console.error('Error fetching locations:', error)
  } finally {
    loading.value = false
  }
}

async function saveLocation() {
  if (!form.value.name.trim()) {
    formError.value = 'Location name is required'
    return
  }

  saving.value = true
  formError.value = ''

  try {
    if (editingId.value) {
      // Update
      const { error } = await supabase
        .from('locations')
        .update({ name: form.value.name.trim() })
        .eq('id', editingId.value)

      if (error) throw error

      // Update local state
      const index = locations.value.findIndex(l => l.id === editingId.value)
      if (index !== -1) {
        locations.value[index].name = form.value.name.trim()
      }
    } else {
      // Create
      const { data, error } = await supabase
        .from('locations')
        .insert({ name: form.value.name.trim() })
        .select()
        .single()

      if (error) throw error
      locations.value.push(data)
      locations.value.sort((a, b) => a.name.localeCompare(b.name))
    }

    closeModal()
  } catch (error: any) {
    formError.value = error.message || 'Failed to save location'
  } finally {
    saving.value = false
  }
}

async function deleteLocation(id: number) {
  if (!confirm('Are you sure? This will affect all staff at this location.')) return

  try {
    const { error } = await supabase.from('locations').delete().eq('id', id)
    if (error) throw error
    locations.value = locations.value.filter(l => l.id !== id)
  } catch (error) {
    console.error('Error deleting location:', error)
  }
}

onMounted(fetchLocations)
</script>

<template>
  <div class="p-6">
    <div class="flex items-center justify-between mb-8">
      <div class="flex items-center gap-3">
        <MapPin class="w-8 h-8 text-primary" />
        <h1 class="text-2xl font-bold">Locations</h1>
      </div>
      <button
        @click="openCreate"
        class="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90"
      >
        <Plus class="w-4 h-4" />
        Add Location
      </button>
    </div>

    <div v-if="loading" class="text-muted-foreground">Loading...</div>

    <div v-else-if="locations.length === 0" class="text-center py-12 text-muted-foreground">
      No locations found. Add your first location!
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <div v-for="location in locations" :key="location.id" class="bg-card border rounded-lg p-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <MapPin class="w-5 h-5 text-muted-foreground" />
            <span class="font-medium">{{ location.name }}</span>
          </div>
          <div class="flex items-center gap-1">
            <button @click="openEdit(location)" class="p-1 hover:bg-muted rounded" title="Edit">
              <Pencil class="w-4 h-4" />
            </button>
            <button @click="deleteLocation(location.id)" class="p-1 hover:bg-muted rounded text-red-500" title="Delete">
              <Trash2 class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <Modal
      :show="showModal"
      :title="editingId ? 'Edit Location' : 'Add Location'"
      @close="closeModal"
    >
      <form @submit.prevent="saveLocation" class="space-y-4">
        <div>
          <label class="block text-sm font-medium mb-2">Location Name</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            placeholder="e.g. HQ Office, Branch A"
            autofocus
          />
        </div>

        <div v-if="formError" class="text-red-500 text-sm">{{ formError }}</div>

        <div class="flex justify-end gap-2 pt-2">
          <button
            type="button"
            @click="closeModal"
            class="px-4 py-2 border rounded-lg hover:bg-muted"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="saving"
            class="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90 disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : (editingId ? 'Update' : 'Create') }}
          </button>
        </div>
      </form>
    </Modal>
  </div>
</template>
