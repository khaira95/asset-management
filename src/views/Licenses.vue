<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { License } from '@/types/database'
import { Key, Plus, Pencil, Trash2, AlertTriangle, Calendar, Users } from 'lucide-vue-next'
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

function getExpirationStatus(date: string | null) {
  if (!date) return { label: 'No expiry', class: 'bg-gray-100 text-gray-600 border-gray-200' }
  if (isExpired(date)) return { label: 'Expired', class: 'bg-red-50 text-red-700 border-red-200' }
  if (isExpiringSoon(date)) return { label: 'Expiring soon', class: 'bg-amber-50 text-amber-700 border-amber-200' }
  return { label: 'Active', class: 'bg-emerald-50 text-emerald-700 border-emerald-200' }
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
  return new Date(date).toLocaleDateString('en-MY', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  })
}

onMounted(fetchLicenses)
</script>

<template>
  <div class="p-6 lg:p-8">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Key class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Licenses</h1>
          <p class="text-sm text-muted-foreground">Track software licenses</p>
        </div>
      </div>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 active:scale-[0.98] transition-all shadow-lg shadow-primary/20"
      >
        <Plus class="w-4 h-4" />
        Add License
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="bg-card border rounded-2xl p-8">
      <div class="animate-pulse space-y-4">
        <div class="h-4 bg-muted rounded w-1/4"></div>
        <div class="h-4 bg-muted rounded w-1/2"></div>
        <div class="h-4 bg-muted rounded w-1/3"></div>
      </div>
    </div>

    <!-- Empty state -->
    <div v-else-if="licenses.length === 0" class="bg-card border rounded-2xl p-12 text-center">
      <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto mb-4">
        <Key class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-semibold text-foreground mb-2">No licenses yet</h3>
      <p class="text-muted-foreground mb-6">Start tracking your software licenses</p>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 transition-all"
      >
        <Plus class="w-4 h-4" />
        Add License
      </button>
    </div>

    <!-- Table -->
    <div v-else class="bg-card border rounded-2xl overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b bg-muted/30">
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">License</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Type</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Seats</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Expiration</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Status</th>
              <th class="px-6 py-4 text-right text-xs font-semibold text-muted-foreground uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr
              v-for="license in licenses"
              :key="license.id"
              class="group hover:bg-muted/30 transition-colors"
            >
              <td class="px-6 py-4">
                <div>
                  <div class="flex items-center gap-2">
                    <p class="font-medium text-foreground">{{ license.name }}</p>
                    <AlertTriangle
                      v-if="isExpiringSoon(license.expiration_date) || isExpired(license.expiration_date)"
                      :class="isExpired(license.expiration_date) ? 'text-red-500' : 'text-amber-500'"
                      class="w-4 h-4"
                    />
                  </div>
                  <p class="text-sm text-muted-foreground font-mono mt-0.5">{{ license.license_key }}</p>
                </div>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm text-foreground">{{ license.type || '-' }}</span>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center gap-1.5">
                  <Users class="w-4 h-4 text-muted-foreground" />
                  <span class="text-sm text-foreground">{{ license.seats_used }} / {{ license.seats_total }}</span>
                </div>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center gap-1.5">
                  <Calendar class="w-4 h-4 text-muted-foreground" />
                  <span class="text-sm text-foreground">{{ formatDate(license.expiration_date) }}</span>
                </div>
              </td>
              <td class="px-6 py-4">
                <span :class="['inline-flex px-2.5 py-1 text-xs font-medium rounded-lg border', getExpirationStatus(license.expiration_date).class]">
                  {{ getExpirationStatus(license.expiration_date).label }}
                </span>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    @click="openEdit(license)"
                    class="p-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
                    title="Edit"
                  >
                    <Pencil class="w-4 h-4" />
                  </button>
                  <button
                    @click="deleteLicense(license.id)"
                    class="p-2 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-lg transition-all"
                    title="Delete"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Table footer -->
      <div class="px-6 py-4 border-t bg-muted/20">
        <p class="text-sm text-muted-foreground">
          {{ licenses.length }} license{{ licenses.length !== 1 ? 's' : '' }}
        </p>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <Modal
      :show="showModal"
      :title="editingId ? 'Edit License' : 'Add License'"
      size="lg"
      @close="closeModal"
    >
      <form @submit.prevent="saveLicense" class="space-y-5">
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">License Name *</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="e.g. Microsoft Office 365"
              autofocus
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Type</label>
            <input
              v-model="form.type"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="e.g. Subscription, Perpetual"
            />
          </div>
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">License Key *</label>
          <input
            v-model="form.license_key"
            type="text"
            class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all font-mono"
            placeholder="XXXXX-XXXXX-XXXXX-XXXXX"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Purchase Date</label>
            <input
              v-model="form.purchased_date"
              type="date"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Expiration Date</label>
            <input
              v-model="form.expiration_date"
              type="date"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            />
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Total Seats</label>
            <input
              v-model.number="form.seats_total"
              type="number"
              min="1"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Seats Used</label>
            <input
              v-model.number="form.seats_used"
              type="number"
              min="0"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Cost (RM)</label>
            <input
              v-model="form.cost"
              type="number"
              step="0.01"
              min="0"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="0.00"
            />
          </div>
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">Notes</label>
          <textarea
            v-model="form.notes"
            rows="2"
            class="w-full px-4 py-3 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all resize-none"
            placeholder="Additional notes..."
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
