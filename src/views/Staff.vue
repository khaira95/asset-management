<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Staff, Location } from '@/types/database'
import { Users, Plus, Pencil, Trash2, Mail, Phone } from 'lucide-vue-next'
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
  <div class="p-6">
    <div class="flex items-center justify-between mb-8">
      <div class="flex items-center gap-3">
        <Users class="w-8 h-8 text-primary" />
        <h1 class="text-2xl font-bold">Staff</h1>
      </div>
      <button
        @click="openCreate"
        class="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90"
      >
        <Plus class="w-4 h-4" />
        Add Staff
      </button>
    </div>

    <div v-if="loading" class="text-muted-foreground">Loading...</div>

    <div v-else-if="staffList.length === 0" class="text-center py-12 text-muted-foreground">
      No staff found. Add your first staff member!
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="staff in staffList" :key="staff.id" class="bg-card border rounded-lg p-4">
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <h3 class="font-semibold">{{ staff.name }}</h3>
            <p class="text-sm text-muted-foreground">{{ staff.staff_id }}</p>
            <p v-if="staff.position" class="text-sm mt-1">{{ staff.position }}</p>
            <p v-if="staff.locations" class="text-sm text-muted-foreground">{{ staff.locations.name }}</p>
            <div class="mt-3 space-y-1">
              <p v-if="staff.email" class="flex items-center gap-2 text-sm text-muted-foreground">
                <Mail class="w-3 h-3" /> {{ staff.email }}
              </p>
              <p v-if="staff.phone_number" class="flex items-center gap-2 text-sm text-muted-foreground">
                <Phone class="w-3 h-3" /> {{ staff.phone_number }}
              </p>
            </div>
          </div>
          <div class="flex items-center gap-1">
            <button @click="openEdit(staff)" class="p-1 hover:bg-muted rounded" title="Edit">
              <Pencil class="w-4 h-4" />
            </button>
            <button @click="deleteStaff(staff.id)" class="p-1 hover:bg-muted rounded text-red-500" title="Delete">
              <Trash2 class="w-4 h-4" />
            </button>
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
      <form @submit.prevent="saveStaff" class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Name *</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Full name"
              autofocus
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Staff ID *</label>
            <input
              v-model="form.staff_id"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="e.g. EMP001"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Position</label>
            <input
              v-model="form.position"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Job title"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Location</label>
            <select
              v-model="form.location_id"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <option value="">Select location</option>
              <option v-for="loc in locations" :key="loc.id" :value="loc.id">
                {{ loc.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Email</label>
            <input
              v-model="form.email"
              type="email"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="email@example.com"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Phone</label>
            <input
              v-model="form.phone_number"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="012-3456789"
            />
          </div>
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
