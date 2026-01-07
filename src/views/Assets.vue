<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Asset, Category, Staff } from '@/types/database'
import { Package, Plus, Pencil, Trash2, Search, Filter, History, Clock } from 'lucide-vue-next'
import type { AssetHistory } from '@/types/database'
import Modal from '@/components/Modal.vue'

interface AssetWithRelations extends Asset {
  categories: Category | null
  staff: Staff | null
}

interface StaffWithLocation extends Staff {
  locations: { name: string } | null
}

const assets = ref<AssetWithRelations[]>([])
const categories = ref<Category[]>([])
const staffList = ref<StaffWithLocation[]>([])
const loading = ref(true)
const saving = ref(false)
const searchQuery = ref('')

// Modal state
const showModal = ref(false)
const editingId = ref<number | null>(null)
const form = ref({
  asset_name: '',
  serial_number: '',
  category_id: '' as string | number,
  status: 'active' as Asset['status'],
  staff_id: '' as string | number,
  purchase_date: '',
  description: '',
  status_date: '' // Date for status change
})
const originalStatus = ref<Asset['status'] | null>(null)
const formError = ref('')

// History modal state
const showHistoryModal = ref(false)
const historyAsset = ref<AssetWithRelations | null>(null)
const assetHistory = ref<AssetHistory[]>([])
const loadingHistory = ref(false)

const statusConfig: Record<string, { label: string; class: string }> = {
  active: { label: 'Active', class: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  maintenance: { label: 'Maintenance', class: 'bg-amber-50 text-amber-700 border-amber-200' },
  inactive: { label: 'Inactive', class: 'bg-gray-100 text-gray-600 border-gray-200' },
  disposed: { label: 'Disposed', class: 'bg-red-50 text-red-700 border-red-200' }
}

const statusOptions = ['active', 'maintenance', 'inactive', 'disposed']

const filteredAssets = ref<AssetWithRelations[]>([])

watch([assets, searchQuery], () => {
  if (!searchQuery.value) {
    filteredAssets.value = assets.value
  } else {
    const query = searchQuery.value.toLowerCase()
    filteredAssets.value = assets.value.filter(a =>
      a.asset_name.toLowerCase().includes(query) ||
      a.serial_number?.toLowerCase().includes(query) ||
      a.categories?.name.toLowerCase().includes(query) ||
      a.staff?.name.toLowerCase().includes(query)
    )
  }
}, { immediate: true })

// Generate next asset name based on category
async function generateAssetName(categoryId: number) {
  const category = categories.value.find(c => c.id === categoryId)
  if (!category) return ''

  const prefix = `KLSB-${category.code}-`

  // Get max number for this category
  const { data } = await supabase
    .from('assets')
    .select('asset_name')
    .like('asset_name', `${prefix}%`)

  let maxNum = 0
  if (data) {
    data.forEach(a => {
      const match = a.asset_name.match(new RegExp(`${prefix}(\\d+)$`))
      if (match) {
        const num = parseInt(match[1])
        if (num > maxNum) maxNum = num
      }
    })
  }

  return `${prefix}${String(maxNum + 1).padStart(3, '0')}`
}

// Watch category change to auto-generate asset name (only for new assets)
watch(() => form.value.category_id, async (newCategoryId) => {
  if (!editingId.value && newCategoryId) {
    form.value.asset_name = await generateAssetName(Number(newCategoryId))
  }
})

function openCreate() {
  editingId.value = null
  originalStatus.value = null
  form.value = {
    asset_name: '',
    serial_number: '',
    category_id: '',
    status: 'active',
    staff_id: '',
    purchase_date: '',
    description: '',
    status_date: ''
  }
  formError.value = ''
  showModal.value = true
}

function openEdit(asset: AssetWithRelations) {
  editingId.value = asset.id
  originalStatus.value = asset.status
  form.value = {
    asset_name: asset.asset_name,
    serial_number: asset.serial_number || '',
    category_id: asset.category_id || '',
    status: asset.status,
    staff_id: asset.staff_id || '',
    purchase_date: asset.purchase_date || '',
    description: asset.description || '',
    status_date: new Date().toISOString().split('T')[0] // Default to today
  }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingId.value = null
  formError.value = ''
}

async function fetchData() {
  try {
    const [assetsRes, catRes, staffRes] = await Promise.all([
      supabase.from('assets').select('*, categories (*), staff (*)').order('created_at', { ascending: false }),
      supabase.from('categories').select('*').order('name'),
      supabase.from('staff').select('*, locations (name)').order('name')
    ])

    if (assetsRes.error) throw assetsRes.error
    if (catRes.error) throw catRes.error
    if (staffRes.error) throw staffRes.error

    assets.value = assetsRes.data || []
    categories.value = catRes.data || []
    staffList.value = staffRes.data || []
  } catch (error) {
    console.error('Error fetching data:', error)
  } finally {
    loading.value = false
  }
}

async function saveAsset() {
  if (!form.value.asset_name.trim()) {
    formError.value = 'Asset name is required'
    return
  }
  if (!form.value.category_id) {
    formError.value = 'Category is required'
    return
  }

  saving.value = true
  formError.value = ''

  const payload = {
    asset_name: form.value.asset_name.trim(),
    serial_number: form.value.serial_number.trim() || null,
    category_id: Number(form.value.category_id),
    status: form.value.status,
    staff_id: form.value.staff_id ? Number(form.value.staff_id) : null,
    purchase_date: form.value.purchase_date || null,
    description: form.value.description.trim() || null
  }

  try {
    if (editingId.value) {
      // Get the old asset for tracking changes
      const oldAsset = assets.value.find(a => a.id === editingId.value)

      const { error } = await supabase
        .from('assets')
        .update(payload)
        .eq('id', editingId.value)

      if (error) throw error

      // Track changes (pass status_date if status changed)
      if (oldAsset) {
        const statusDate = form.value.status !== originalStatus.value ? form.value.status_date : undefined
        await trackChanges(editingId.value, oldAsset, payload, statusDate)
      }
    } else {
      const { data, error } = await supabase.from('assets').insert(payload).select().single()
      if (error) throw error

      // Track asset creation
      const { data: { user } } = await supabase.auth.getUser()
      if (user && data) {
        await supabase.from('asset_history').insert({
          asset_id: data.id,
          user_id: user.id,
          field_name: 'asset',
          old_value: null,
          new_value: payload.asset_name,
          change_type: 'create'
        })
      }
    }

    await fetchData()
    closeModal()
  } catch (error: any) {
    if (error.message?.includes('duplicate') || error.code === '23505') {
      if (error.message?.includes('asset_name')) {
        formError.value = 'Asset name already exists'
      } else if (error.message?.includes('serial_number')) {
        formError.value = 'Serial number already exists'
      } else {
        formError.value = 'Duplicate entry'
      }
    } else {
      formError.value = error.message || 'Failed to save asset'
    }
  } finally {
    saving.value = false
  }
}

async function deleteAsset(id: number) {
  if (!confirm('Are you sure you want to delete this asset?')) return

  try {
    const { error } = await supabase.from('assets').delete().eq('id', id)
    if (error) throw error
    assets.value = assets.value.filter(a => a.id !== id)
  } catch (error) {
    console.error('Error deleting asset:', error)
  }
}

// History functions
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

async function openHistory(asset: AssetWithRelations) {
  historyAsset.value = asset
  showHistoryModal.value = true
  loadingHistory.value = true

  try {
    const { data, error } = await supabase
      .from('asset_history')
      .select('*')
      .eq('asset_id', asset.id)
      .order('created_at', { ascending: false })

    if (error) throw error
    assetHistory.value = data || []
  } catch (error) {
    console.error('Error fetching history:', error)
    assetHistory.value = []
  } finally {
    loadingHistory.value = false
  }
}

function closeHistoryModal() {
  showHistoryModal.value = false
  historyAsset.value = null
  assetHistory.value = []
}

async function trackChanges(assetId: number, oldAsset: AssetWithRelations, newData: any, statusDate?: string) {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      console.error('No user found for tracking changes')
      return
    }

    const changes: { field_name: string; old_value: string | null; new_value: string | null; custom_date?: string }[] = []

    // Compare fields - use String() for consistent comparison
    const oldStatus = String(oldAsset.status || '')
    const newStatus = String(newData.status || '')
    if (oldStatus !== newStatus) {
      changes.push({
        field_name: 'status',
        old_value: oldAsset.status,
        new_value: newData.status,
        custom_date: statusDate // Use custom date for status changes
      })
    }

    const oldStaffId = oldAsset.staff_id ? Number(oldAsset.staff_id) : null
    const newStaffId = newData.staff_id ? Number(newData.staff_id) : null
    if (oldStaffId !== newStaffId) {
      const oldStaff = staffList.value.find(s => s.id === oldStaffId)?.name || null
      const newStaff = staffList.value.find(s => s.id === newStaffId)?.name || null
      changes.push({ field_name: 'assigned_to', old_value: oldStaff, new_value: newStaff })
    }

    const oldCatId = oldAsset.category_id ? Number(oldAsset.category_id) : null
    const newCatId = newData.category_id ? Number(newData.category_id) : null
    if (oldCatId !== newCatId) {
      const oldCat = categories.value.find(c => c.id === oldCatId)?.name || null
      const newCat = categories.value.find(c => c.id === newCatId)?.name || null
      changes.push({ field_name: 'category', old_value: oldCat, new_value: newCat })
    }

    const oldSerial = String(oldAsset.serial_number || '')
    const newSerial = String(newData.serial_number || '')
    if (oldSerial !== newSerial) {
      changes.push({ field_name: 'serial_number', old_value: oldAsset.serial_number, new_value: newData.serial_number })
    }

    const oldDesc = String(oldAsset.description || '')
    const newDesc = String(newData.description || '')
    if (oldDesc !== newDesc) {
      changes.push({ field_name: 'description', old_value: oldAsset.description, new_value: newData.description })
    }

    const oldDate = String(oldAsset.purchase_date || '')
    const newDate = String(newData.purchase_date || '')
    if (oldDate !== newDate) {
      changes.push({ field_name: 'purchase_date', old_value: oldAsset.purchase_date, new_value: newData.purchase_date })
    }

    // Insert all changes
    for (const change of changes) {
      const insertData: any = {
        asset_id: assetId,
        user_id: user.id,
        field_name: change.field_name,
        old_value: change.old_value,
        new_value: change.new_value,
        change_type: 'update'
      }

      // Use effective_date for status changes (the date when status actually changed)
      if (change.custom_date) {
        insertData.effective_date = change.custom_date
      }

      const { error } = await supabase.from('asset_history').insert(insertData)
      if (error) {
        console.error('Error inserting history:', error)
      }
    }
  } catch (error) {
    console.error('Error tracking changes:', error)
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
          <Package class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Assets</h1>
          <p class="text-sm text-muted-foreground">Manage your inventory items</p>
        </div>
      </div>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 active:scale-[0.98] transition-all shadow-lg shadow-primary/20"
      >
        <Plus class="w-4 h-4" />
        Add Asset
      </button>
    </div>

    <!-- Search bar -->
    <div class="mb-6">
      <div class="relative max-w-md">
        <Search class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search assets..."
          class="w-full h-11 pl-11 pr-4 bg-card border rounded-xl text-foreground placeholder:text-muted-foreground/60 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
        />
      </div>
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
    <div v-else-if="assets.length === 0" class="bg-card border rounded-2xl p-12 text-center">
      <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto mb-4">
        <Package class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-semibold text-foreground mb-2">No assets yet</h3>
      <p class="text-muted-foreground mb-6">Get started by adding your first asset</p>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 transition-all"
      >
        <Plus class="w-4 h-4" />
        Add Asset
      </button>
    </div>

    <!-- Table -->
    <div v-else class="bg-card border rounded-2xl overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b bg-muted/30">
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Asset</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Category</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Status</th>
              <th class="px-6 py-4 text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider">Assigned To</th>
              <th class="px-6 py-4 text-right text-xs font-semibold text-muted-foreground uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr
              v-for="asset in filteredAssets"
              :key="asset.id"
              class="group hover:bg-muted/30 transition-colors"
            >
              <td class="px-6 py-4">
                <div>
                  <p class="font-medium text-foreground">{{ asset.asset_name }}</p>
                  <p class="text-sm text-muted-foreground">{{ asset.serial_number || 'No serial' }}</p>
                </div>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm text-foreground">{{ asset.categories?.name || '-' }}</span>
              </td>
              <td class="px-6 py-4">
                <span :class="['inline-flex px-2.5 py-1 text-xs font-medium rounded-lg border', statusConfig[asset.status]?.class]">
                  {{ statusConfig[asset.status]?.label }}
                </span>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm text-foreground">{{ asset.staff?.name || '-' }}</span>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    @click="openHistory(asset)"
                    class="p-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
                    title="View History"
                  >
                    <History class="w-4 h-4" />
                  </button>
                  <button
                    @click="openEdit(asset)"
                    class="p-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
                    title="Edit"
                  >
                    <Pencil class="w-4 h-4" />
                  </button>
                  <button
                    @click="deleteAsset(asset.id)"
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
          Showing {{ filteredAssets.length }} of {{ assets.length }} assets
        </p>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <Modal
      :show="showModal"
      :title="editingId ? 'Edit Asset' : 'Add Asset'"
      size="lg"
      @close="closeModal"
    >
      <form @submit.prevent="saveAsset" class="space-y-5">
        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Category *</label>
            <select
              v-model="form.category_id"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            >
              <option value="">Select category</option>
              <option v-for="cat in categories" :key="cat.id" :value="cat.id">
                {{ cat.name }} ({{ cat.code }})
              </option>
            </select>
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Asset Name *</label>
            <input
              v-model="form.asset_name"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all disabled:opacity-60"
              placeholder="Auto-generated"
              :disabled="!editingId"
            />
            <p v-if="!editingId" class="text-xs text-muted-foreground">Auto-generated from category</p>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Serial Number</label>
            <input
              v-model="form.serial_number"
              type="text"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="e.g. SN123456789"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Status</label>
            <select
              v-model="form.status"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            >
              <option v-for="status in statusOptions" :key="status" :value="status">
                {{ status.charAt(0).toUpperCase() + status.slice(1) }}
              </option>
            </select>
          </div>
        </div>

        <!-- Status Change Date (only show when editing and status changed) -->
        <div v-if="editingId && form.status !== originalStatus" class="p-4 bg-amber-50 border border-amber-200 rounded-xl">
          <div class="flex items-start gap-3">
            <div class="w-8 h-8 rounded-lg bg-amber-100 flex items-center justify-center flex-shrink-0">
              <Clock class="w-4 h-4 text-amber-600" />
            </div>
            <div class="flex-1">
              <p class="text-sm font-medium text-amber-800 mb-2">
                Status change: {{ originalStatus }} → {{ form.status }}
              </p>
              <div class="space-y-1">
                <label class="block text-xs font-medium text-amber-700">Date of status change</label>
                <input
                  v-model="form.status_date"
                  type="date"
                  class="w-full h-10 px-3 bg-white border border-amber-300 rounded-lg text-foreground focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all"
                />
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Assigned To</label>
            <select
              v-model="form.staff_id"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            >
              <option value="">Unassigned</option>
              <option v-for="staff in staffList" :key="staff.id" :value="staff.id">
                {{ staff.name }} ({{ staff.staff_id }})
              </option>
            </select>
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Purchase Date</label>
            <input
              v-model="form.purchase_date"
              type="date"
              class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            />
          </div>
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">Description</label>
          <textarea
            v-model="form.description"
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

    <!-- History Modal -->
    <Modal
      :show="showHistoryModal"
      :title="`History: ${historyAsset?.asset_name || ''}`"
      size="lg"
      @close="closeHistoryModal"
    >
      <div v-if="loadingHistory" class="py-8 text-center">
        <div class="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full mx-auto mb-2"></div>
        <p class="text-sm text-muted-foreground">Loading history...</p>
      </div>

      <div v-else-if="assetHistory.length === 0" class="py-12 text-center">
        <History class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
        <p class="text-muted-foreground">No history recorded yet</p>
        <p class="text-sm text-muted-foreground/70 mt-1">Changes will appear here after edits</p>
      </div>

      <div v-else class="space-y-3 max-h-96 overflow-y-auto">
        <div
          v-for="history in assetHistory"
          :key="history.id"
          class="flex items-start gap-3 p-3 bg-muted/30 rounded-xl"
        >
          <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0 mt-0.5">
            <Clock class="w-4 h-4 text-primary" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between gap-2 mb-1">
              <span :class="[
                'px-2 py-0.5 text-xs font-medium rounded',
                history.change_type === 'create' ? 'bg-emerald-100 text-emerald-700' : 'bg-blue-100 text-blue-700'
              ]">
                {{ history.change_type === 'create' ? 'Created' : 'Updated' }}
              </span>
              <div class="text-right">
                <p class="text-xs font-medium text-foreground">{{ formatDateTime(new Date(history.created_at)) }}</p>
                <p class="text-xs text-muted-foreground">{{ formatTimeAgo(new Date(history.created_at)) }}</p>
              </div>
            </div>
            <p class="text-sm text-foreground">
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

      <div class="flex justify-end pt-4 mt-4 border-t">
        <button
          @click="closeHistoryModal"
          class="px-4 py-2.5 border rounded-xl font-medium text-foreground hover:bg-muted transition-all"
        >
          Close
        </button>
      </div>
    </Modal>
  </div>
</template>
