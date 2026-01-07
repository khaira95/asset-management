<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Staff, Location, Asset, Category, AssetHistory } from '@/types/database'
import { Users, Plus, Pencil, Trash2, Mail, Phone, MapPin, Package, Eye, Clock, ChevronDown, ChevronUp } from 'lucide-vue-next'
import Modal from '@/components/Modal.vue'

interface StaffWithLocation extends Staff {
  locations: Location | null
  asset_count?: number
}

interface AssetWithDetails extends Asset {
  categories: Category | null
  history: AssetHistory[]
  showHistory?: boolean
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

// Assets modal state
const showAssetsModal = ref(false)
const selectedStaff = ref<StaffWithLocation | null>(null)
const staffAssets = ref<AssetWithDetails[]>([])
const loadingAssets = ref(false)

const statusConfig: Record<string, { label: string; class: string }> = {
  active: { label: 'Active', class: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  maintenance: { label: 'Maintenance', class: 'bg-amber-50 text-amber-700 border-amber-200' },
  inactive: { label: 'Inactive', class: 'bg-gray-100 text-gray-600 border-gray-200' },
  disposed: { label: 'Disposed', class: 'bg-red-50 text-red-700 border-red-200' }
}

function formatDateTime(date: Date): string {
  return date.toLocaleString('en-MY', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  })
}

function formatTimeAgo(date: Date): string {
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return 'Just now'
  if (diffMins < 60) return `${diffMins} min ago`
  if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`
  if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`
  return date.toLocaleDateString()
}

async function openAssetsModal(staff: StaffWithLocation) {
  selectedStaff.value = staff
  showAssetsModal.value = true
  loadingAssets.value = true

  try {
    // Fetch assets for this staff
    const { data: assetsData, error: assetsError } = await supabase
      .from('assets')
      .select('*, categories (*)')
      .eq('staff_id', staff.id)
      .order('asset_name')

    if (assetsError) throw assetsError

    // Fetch history for all these assets
    const assetIds = (assetsData || []).map(a => a.id)
    let historyData: AssetHistory[] = []

    if (assetIds.length > 0) {
      const { data, error: historyError } = await supabase
        .from('asset_history')
        .select('*')
        .in('asset_id', assetIds)
        .order('created_at', { ascending: false })

      if (!historyError) {
        historyData = data || []
      }
    }

    // Group history by asset_id
    const historyByAsset: Record<number, AssetHistory[]> = {}
    historyData.forEach(h => {
      if (!historyByAsset[h.asset_id]) {
        historyByAsset[h.asset_id] = []
      }
      historyByAsset[h.asset_id].push(h)
    })

    // Combine assets with their history
    staffAssets.value = (assetsData || []).map(asset => ({
      ...asset,
      history: historyByAsset[asset.id] || [],
      showHistory: false
    }))
  } catch (error) {
    console.error('Error fetching staff assets:', error)
    staffAssets.value = []
  } finally {
    loadingAssets.value = false
  }
}

function closeAssetsModal() {
  showAssetsModal.value = false
  selectedStaff.value = null
  staffAssets.value = []
}

function toggleAssetHistory(asset: AssetWithDetails) {
  asset.showHistory = !asset.showHistory
}

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
    const [staffRes, locRes, assetsRes] = await Promise.all([
      supabase.from('staff').select('*, locations (*)').order('name'),
      supabase.from('locations').select('*').order('name'),
      supabase.from('assets').select('staff_id')
    ])

    if (staffRes.error) throw staffRes.error
    if (locRes.error) throw locRes.error

    // Count assets per staff
    const assetCounts: Record<number, number> = {}
    if (assetsRes.data) {
      assetsRes.data.forEach(asset => {
        if (asset.staff_id) {
          assetCounts[asset.staff_id] = (assetCounts[asset.staff_id] || 0) + 1
        }
      })
    }

    // Add asset count to each staff
    staffList.value = (staffRes.data || []).map(staff => ({
      ...staff,
      asset_count: assetCounts[staff.id] || 0
    }))
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
              <button
                v-if="staff.asset_count > 0"
                @click="openAssetsModal(staff)"
                class="flex items-center gap-2 text-sm text-primary hover:text-primary/80 transition-colors"
              >
                <Package class="w-3.5 h-3.5" />
                <span class="font-medium">{{ staff.asset_count }} asset{{ staff.asset_count !== 1 ? 's' : '' }}</span>
                <Eye class="w-3 h-3" />
              </button>
              <p v-else class="flex items-center gap-2 text-sm text-muted-foreground">
                <Package class="w-3.5 h-3.5" />
                <span>0 assets</span>
              </p>
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

    <!-- Assets Modal -->
    <Modal
      :show="showAssetsModal"
      :title="`Assets: ${selectedStaff?.name || ''}`"
      size="lg"
      @close="closeAssetsModal"
    >
      <div v-if="loadingAssets" class="py-8 text-center">
        <div class="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full mx-auto mb-2"></div>
        <p class="text-sm text-muted-foreground">Loading assets...</p>
      </div>

      <div v-else-if="staffAssets.length === 0" class="py-12 text-center">
        <Package class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
        <p class="text-muted-foreground">No assets assigned</p>
      </div>

      <div v-else class="space-y-3 max-h-[60vh] overflow-y-auto">
        <div
          v-for="asset in staffAssets"
          :key="asset.id"
          class="border rounded-xl overflow-hidden"
        >
          <!-- Asset Header -->
          <div class="p-4 bg-muted/30">
            <div class="flex items-start justify-between gap-3">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <h4 class="font-semibold text-foreground">{{ asset.asset_name }}</h4>
                  <span :class="['px-2 py-0.5 text-xs font-medium rounded-full border', statusConfig[asset.status]?.class]">
                    {{ statusConfig[asset.status]?.label }}
                  </span>
                </div>
                <div class="flex items-center gap-3 text-sm text-muted-foreground">
                  <span v-if="asset.categories">{{ asset.categories.name }}</span>
                  <span v-if="asset.serial_number">SN: {{ asset.serial_number }}</span>
                </div>
              </div>
              <button
                @click="toggleAssetHistory(asset)"
                class="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
              >
                <Clock class="w-3.5 h-3.5" />
                History ({{ asset.history.length }})
                <ChevronDown v-if="!asset.showHistory" class="w-3.5 h-3.5" />
                <ChevronUp v-else class="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          <!-- Asset History (Collapsible) -->
          <div v-if="asset.showHistory" class="border-t">
            <div v-if="asset.history.length === 0" class="p-4 text-center">
              <p class="text-sm text-muted-foreground">No history recorded</p>
            </div>
            <div v-else class="divide-y">
              <div
                v-for="history in asset.history"
                :key="history.id"
                class="p-3 flex items-start gap-3"
              >
                <div class="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 mt-0.5">
                  <Clock class="w-3 h-3 text-primary" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between gap-2">
                    <span :class="[
                      'px-1.5 py-0.5 text-xs font-medium rounded',
                      history.change_type === 'create' ? 'bg-emerald-100 text-emerald-700' : 'bg-blue-100 text-blue-700'
                    ]">
                      {{ history.change_type === 'create' ? 'Created' : 'Updated' }}
                    </span>
                    <div class="text-right">
                      <p class="text-xs font-medium text-foreground">{{ formatDateTime(new Date(history.created_at)) }}</p>
                      <p class="text-xs text-muted-foreground">{{ formatTimeAgo(new Date(history.created_at)) }}</p>
                    </div>
                  </div>
                  <p class="text-sm text-foreground mt-1">
                    <span class="font-medium capitalize">{{ history.field_name.replace('_', ' ') }}</span>
                    <template v-if="history.change_type === 'create'">
                      : {{ history.new_value }}
                    </template>
                    <template v-else>
                      changed from <span class="text-muted-foreground">{{ history.old_value || 'empty' }}</span>
                      to <span class="font-medium">{{ history.new_value || 'empty' }}</span>
                    </template>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="flex justify-end pt-4 mt-4 border-t">
        <button
          @click="closeAssetsModal"
          class="px-4 py-2.5 border rounded-xl font-medium text-foreground hover:bg-muted transition-all"
        >
          Close
        </button>
      </div>
    </Modal>
  </div>
</template>
