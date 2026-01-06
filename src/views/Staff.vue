<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Staff, Location } from '@/types/database'
import { Users, Plus, Pencil, Trash2, Mail, Phone, MapPin, User } from 'lucide-vue-next'
import Modal from '@/components/Modal.vue'

interface StaffWithLocation extends Staff {
  locations: Location | null
}

const staffList = ref<StaffWithLocation[]>([])
const locations = ref<Location[]>([])
const loading = ref(true)
const saving = ref(false)

// Modal state
const showModal = ref(false)
const editingId = ref<number | null>(null)
const form = ref({
  name: '',
  staff_id: '',
  position: '',
  email: '',
  phone_number: '',
  location_id: '' as string | number
})
const formError = ref('')

function openCreate() {
  editingId.value = null
  form.value = { name: '', staff_id: '', position: '', email: '', phone_number: '', location_id: '' }
  formError.value = ''
  showModal.value = true
}

function openEdit(staff: StaffWithLocation) {
  editingId.value = staff.id
  form.value = {
    name: staff.name,
    staff_id: staff.staff_id,
    position: staff.position || '',
    email: staff.email || '',
    phone_number: staff.phone_number || '',
    location_id: staff.location_id || ''
  }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingId.value = null
  form.value = { name: '', staff_id: '', position: '', email: '', phone_number: '', location_id: '' }
  formError.value = ''
}

async function fetchData() {
  try {
    const [staffRes, locRes] = await Promise.all([
      supabase.from('staff').select('*, locations (*)').order('name'),
      supabase.from('locations').select('*').order('name')
    ])

    if (staffRes.error) throw staffRes.error
    if (locRes.error) throw locRes.error

    staffList.value = staffRes.data || []
    locations.value = locRes.data || []
  } catch (error) {
    console.error('Error fetching data:', error)
  } finally {
    loading.value = false
  }
}

async function saveStaff() {
  if (!form.value.name.trim()) {
    formError.value = 'Name is required'
    return
  }
  if (!form.value.staff_id.trim()) {
    formError.value = 'Staff ID is required'
    return
  }

  saving.value = true
  formError.value = ''

  const payload = {
    name: form.value.name.trim(),
    staff_id: form.value.staff_id.trim(),
    position: form.value.position.trim() || null,
    email: form.value.email.trim() || null,
    phone_number: form.value.phone_number.trim() || null,
    location_id: form.value.location_id ? Number(form.value.location_id) : null
  }

  try {
    if (editingId.value) {
      const { error } = await supabase
        .from('staff')
        .update(payload)
        .eq('id', editingId.value)

      if (error) throw error
      // Refetch to get updated relations
      await fetchData()
    } else {
      const { error } = await supabase.from('staff').insert(payload)
      if (error) throw error
      await fetchData()
    }

    closeModal()
  } catch (error: any) {
    if (error.message?.includes('duplicate') || error.code === '23505') {
      formError.value = 'Staff ID already exists'
    } else {
      formError.value = error.message || 'Failed to save staff'
    }
  } finally {
    saving.value = false
  }
}

async function deleteStaff(id: number) {
  if (!confirm('Are you sure you want to delete this staff member?')) return

  try {
    const { error } = await supabase.from('staff').delete().eq('id', id)
    if (error) throw error
    staffList.value = staffList.value.filter(s => s.id !== id)
  } catch (error) {
    console.error('Error deleting staff:', error)
  }
}

onMounted(fetchData)
</script>

<template>
  <div class="p-6 lg:p-8">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Users class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Staff</h1>
          <p class="text-sm text-muted-foreground">Manage team members</p>
        </div>
      </div>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 active:scale-[0.98] transition-all shadow-lg shadow-primary/20"
      >
        <Plus class="w-4 h-4" />
        Add Staff
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="i in 6" :key="i" class="h-40 bg-card border rounded-2xl animate-pulse" />
    </div>

    <!-- Empty state -->
    <div v-else-if="staffList.length === 0" class="bg-card border rounded-2xl p-12 text-center">
      <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto mb-4">
        <Users class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-semibold text-foreground mb-2">No staff yet</h3>
      <p class="text-muted-foreground mb-6">Add team members to assign assets</p>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 transition-all"
      >
        <Plus class="w-4 h-4" />
        Add Staff
      </button>
    </div>

    <!-- Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 stagger-children">
      <div
        v-for="staff in staffList"
        :key="staff.id"
        class="group bg-card border rounded-2xl p-5 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300"
      >
        <div class="flex items-start gap-4">
          <!-- Avatar -->
          <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
            <span class="text-lg font-semibold text-primary">
              {{ staff.name.charAt(0).toUpperCase() }}
            </span>
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between">
              <div>
                <h3 class="font-semibold text-foreground">{{ staff.name }}</h3>
                <p class="text-sm text-muted-foreground">{{ staff.staff_id }}</p>
              </div>
              <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  @click="openEdit(staff)"
                  class="p-1.5 text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
                  title="Edit"
                >
                  <Pencil class="w-3.5 h-3.5" />
                </button>
                <button
                  @click="deleteStaff(staff.id)"
                  class="p-1.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-lg transition-all"
                  title="Delete"
                >
                  <Trash2 class="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

            <p v-if="staff.position" class="text-sm text-foreground mt-2">{{ staff.position }}</p>

            <div class="mt-3 space-y-1.5">
              <p v-if="staff.locations" class="flex items-center gap-2 text-sm text-muted-foreground">
                <MapPin class="w-3.5 h-3.5" />
                {{ staff.locations.name }}
              </p>
              <p v-if="staff.email" class="flex items-center gap-2 text-sm text-muted-foreground truncate">
                <Mail class="w-3.5 h-3.5 flex-shrink-0" />
                {{ staff.email }}
              </p>
              <p v-if="staff.phone_number" class="flex items-center gap-2 text-sm text-muted-foreground">
                <Phone class="w-3.5 h-3.5" />
                {{ staff.phone_number }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <Modal
      :show="showModal"
      :title="editingId ? 'Edit Staff' : 'Add Staff'"
      size="md"
      @close="closeModal"
    >
      <form @submit.prevent="saveStaff" class="space-y-5">
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Name *</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="Full name"
              autofocus
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Staff ID *</label>
            <input
              v-model="form.staff_id"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="e.g. EMP001"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Position</label>
            <input
              v-model="form.position"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="Job title"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Location</label>
            <select
              v-model="form.location_id"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            >
              <option value="">Select location</option>
              <option v-for="loc in locations" :key="loc.id" :value="loc.id">
                {{ loc.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Email</label>
            <input
              v-model="form.email"
              type="email"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="email@example.com"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Phone</label>
            <input
              v-model="form.phone_number"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="012-3456789"
            />
          </div>
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
