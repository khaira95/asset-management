<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Location } from '@/types/database'
import { MapPin, Plus, Pencil, Trash2, Building2, Users } from 'lucide-vue-next'
import Modal from '@/components/Modal.vue'

interface LocationWithCount extends Location {
  staff_count?: number
}

const locations = ref<LocationWithCount[]>([])
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
    const [locRes, staffRes] = await Promise.all([
      supabase.from('locations').select('*').order('name'),
      supabase.from('staff').select('location_id')
    ])

    if (locRes.error) throw locRes.error

    // Count staff per location
    const staffCounts: Record<number, number> = {}
    if (staffRes.data) {
      staffRes.data.forEach(staff => {
        if (staff.location_id) {
          staffCounts[staff.location_id] = (staffCounts[staff.location_id] || 0) + 1
        }
      })
    }

    // Add staff count to each location
    locations.value = (locRes.data || []).map(loc => ({
      ...loc,
      staff_count: staffCounts[loc.id] || 0
    }))
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
  <div class="p-6 lg:p-8">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <MapPin class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Locations</h1>
          <p class="text-sm text-muted-foreground">Manage office locations</p>
        </div>
      </div>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 active:scale-[0.98] transition-all shadow-lg shadow-primary/20"
      >
        <Plus class="w-4 h-4" />
        Add Location
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <div v-for="i in 8" :key="i" class="h-20 bg-card border rounded-2xl animate-pulse" />
    </div>

    <!-- Empty state -->
    <div v-else-if="locations.length === 0" class="bg-card border rounded-2xl p-12 text-center">
      <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto mb-4">
        <MapPin class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-semibold text-foreground mb-2">No locations yet</h3>
      <p class="text-muted-foreground mb-6">Add office locations for staff assignments</p>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 transition-all"
      >
        <Plus class="w-4 h-4" />
        Add Location
      </button>
    </div>

    <!-- Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 stagger-children">
      <div
        v-for="location in locations"
        :key="location.id"
        class="group bg-card border rounded-2xl p-4 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3 min-w-0">
            <div class="w-10 h-10 rounded-xl bg-sky-50 flex items-center justify-center flex-shrink-0">
              <Building2 class="w-5 h-5 text-sky-600" />
            </div>
            <div class="min-w-0">
              <span class="font-medium text-foreground truncate block">{{ location.name }}</span>
              <span class="flex items-center gap-1 text-xs mt-0.5">
                <Users class="w-3 h-3 text-violet-500" />
                <span :class="location.staff_count > 0 ? 'text-foreground' : 'text-muted-foreground'">
                  {{ location.staff_count }} staff
                </span>
              </span>
            </div>
          </div>
          <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity ml-2">
            <button
              @click="openEdit(location)"
              class="p-1.5 text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
              title="Edit"
            >
              <Pencil class="w-3.5 h-3.5" />
            </button>
            <button
              @click="deleteLocation(location.id)"
              class="p-1.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-lg transition-all"
              title="Delete"
            >
              <Trash2 class="w-3.5 h-3.5" />
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
      <form @submit.prevent="saveLocation" class="space-y-5">
        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">Location Name *</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            placeholder="e.g. HQ Office, Branch A"
            autofocus
          />
        </div>

        <!-- Error -->
        <div v-if="formError" class="p-3 bg-destructive/10 border border-destructive/20 rounded-xl">
          <p class="text-sm text-destructive">{{ formError }}</p>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 pt-2">
          <button
            type="button"
            @click="closeModal"
            class="px-4 py-2.5 border rounded-xl font-medium text-foreground hover:bg-muted transition-all"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="saving"
            class="px-5 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 disabled:opacity-50 transition-all"
          >
            {{ saving ? 'Saving...' : (editingId ? 'Update' : 'Create') }}
          </button>
        </div>
      </form>
    </Modal>
  </div>
</template>
