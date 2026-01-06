<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { License } from '@/types/database'
import { Key, Plus, Pencil, Trash2, AlertTriangle } from 'lucide-vue-next'
import Modal from '@/components/Modal.vue'

const licenses = ref<License[]>([])
const loading = ref(true)
const saving = ref(false)

// Modal state
const showModal = ref(false)
const editingId = ref<number | null>(null)
const form = ref({
  name: '',
  license_key: '',
  type: '',
  purchased_date: '',
  expiration_date: '',
  seats_total: 1,
  seats_used: 0,
  cost: '',
  notes: ''
})
const formError = ref('')

function isExpiringSoon(date: string | null): boolean {
  if (!date) return false
  const expDate = new Date(date)
  const today = new Date()
  const thirtyDays = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000)
  return expDate <= thirtyDays && expDate >= today
}

function isExpired(date: string | null): boolean {
  if (!date) return false
  return new Date(date) < new Date()
}

function openCreate() {
  editingId.value = null
  form.value = {
    name: '',
    license_key: '',
    type: '',
    purchased_date: '',
    expiration_date: '',
    seats_total: 1,
    seats_used: 0,
    cost: '',
    notes: ''
  }
  formError.value = ''
  showModal.value = true
}

function openEdit(license: License) {
  editingId.value = license.id
  form.value = {
    name: license.name,
    license_key: license.license_key,
    type: license.type || '',
    purchased_date: license.purchased_date || '',
    expiration_date: license.expiration_date || '',
    seats_total: license.seats_total,
    seats_used: license.seats_used,
    cost: license.cost?.toString() || '',
    notes: license.notes || ''
  }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingId.value = null
  formError.value = ''
}

async function fetchLicenses() {
  try {
    const { data, error } = await supabase
      .from('licenses')
      .select('*')
      .order('expiration_date')

    if (error) throw error
    licenses.value = data || []
  } catch (error) {
    console.error('Error fetching licenses:', error)
  } finally {
    loading.value = false
  }
}

async function saveLicense() {
  if (!form.value.name.trim()) {
    formError.value = 'License name is required'
    return
  }
  if (!form.value.license_key.trim()) {
    formError.value = 'License key is required'
    return
  }

  saving.value = true
  formError.value = ''

  const payload = {
    name: form.value.name.trim(),
    license_key: form.value.license_key.trim(),
    type: form.value.type.trim() || null,
    purchased_date: form.value.purchased_date || null,
    expiration_date: form.value.expiration_date || null,
    seats_total: Number(form.value.seats_total) || 1,
    seats_used: Number(form.value.seats_used) || 0,
    cost: form.value.cost ? parseFloat(form.value.cost) : null,
    notes: form.value.notes.trim() || null
  }

  try {
    if (editingId.value) {
      const { error } = await supabase
        .from('licenses')
        .update(payload)
        .eq('id', editingId.value)

      if (error) throw error
    } else {
      const { error } = await supabase.from('licenses').insert(payload)
      if (error) throw error
    }

    await fetchLicenses()
    closeModal()
  } catch (error: any) {
    if (error.message?.includes('duplicate') || error.code === '23505') {
      formError.value = 'License key already exists'
    } else {
      formError.value = error.message || 'Failed to save license'
    }
  } finally {
    saving.value = false
  }
}

async function deleteLicense(id: number) {
  if (!confirm('Are you sure you want to delete this license?')) return

  try {
    const { error } = await supabase.from('licenses').delete().eq('id', id)
    if (error) throw error
    licenses.value = licenses.value.filter(l => l.id !== id)
  } catch (error) {
    console.error('Error deleting license:', error)
  }
}

function formatDate(date: string | null): string {
  if (!date) return '-'
  return new Date(date).toLocaleDateString()
}

onMounted(fetchLicenses)
</script>

<template>
  <div class="p-6">
    <div class="flex items-center justify-between mb-8">
      <div class="flex items-center gap-3">
        <Key class="w-8 h-8 text-primary" />
        <h1 class="text-2xl font-bold">Licenses</h1>
      </div>
      <button
        @click="openCreate"
        class="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90"
      >
        <Plus class="w-4 h-4" />
        Add License
      </button>
    </div>

    <div v-if="loading" class="text-muted-foreground">Loading...</div>

    <div v-else-if="licenses.length === 0" class="text-center py-12 text-muted-foreground">
      No licenses found. Add your first license!
    </div>

    <div v-else class="bg-card border rounded-lg overflow-hidden overflow-x-auto">
      <table class="w-full">
        <thead class="bg-muted/50">
          <tr>
            <th class="px-4 py-3 text-left text-sm font-medium">Name</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Type</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Seats</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Expiration</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="license in licenses" :key="license.id" class="hover:bg-muted/30">
            <td class="px-4 py-3">
              <div>
                <div class="font-medium flex items-center gap-2">
                  {{ license.name }}
                  <AlertTriangle
                    v-if="isExpiringSoon(license.expiration_date) || isExpired(license.expiration_date)"
                    :class="isExpired(license.expiration_date) ? 'text-red-500' : 'text-yellow-500'"
                    class="w-4 h-4"
                  />
                </div>
                <div class="text-sm text-muted-foreground font-mono">{{ license.license_key }}</div>
              </div>
            </td>
            <td class="px-4 py-3">{{ license.type || '-' }}</td>
            <td class="px-4 py-3">{{ license.seats_used }} / {{ license.seats_total }}</td>
            <td class="px-4 py-3">
              <span :class="{ 'text-red-500': isExpired(license.expiration_date), 'text-yellow-500': isExpiringSoon(license.expiration_date) }">
                {{ formatDate(license.expiration_date) }}
              </span>
            </td>
            <td class="px-4 py-3">
              <div class="flex items-center gap-2">
                <button @click="openEdit(license)" class="p-1 hover:bg-muted rounded" title="Edit">
                  <Pencil class="w-4 h-4" />
                </button>
                <button @click="deleteLicense(license.id)" class="p-1 hover:bg-muted rounded text-red-500" title="Delete">
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Create/Edit Modal -->
    <Modal
      :show="showModal"
      :title="editingId ? 'Edit License' : 'Add License'"
      size="lg"
      @close="closeModal"
    >
      <form @submit.prevent="saveLicense" class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">License Name *</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="e.g. Microsoft Office 365"
              autofocus
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Type</label>
            <input
              v-model="form.type"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="e.g. Subscription, Perpetual"
            />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">License Key *</label>
          <input
            v-model="form.license_key"
            type="text"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary font-mono"
            placeholder="XXXXX-XXXXX-XXXXX-XXXXX"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Purchase Date</label>
            <input
              v-model="form.purchased_date"
              type="date"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Expiration Date</label>
            <input
              v-model="form.expiration_date"
              type="date"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Total Seats</label>
            <input
              v-model.number="form.seats_total"
              type="number"
              min="1"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Seats Used</label>
            <input
              v-model.number="form.seats_used"
              type="number"
              min="0"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Cost (RM)</label>
            <input
              v-model="form.cost"
              type="number"
              step="0.01"
              min="0"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="0.00"
            />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Notes</label>
          <textarea
            v-model="form.notes"
            rows="2"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary resize-none"
            placeholder="Additional notes about this license"
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
