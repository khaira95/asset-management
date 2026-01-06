<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Asset, Category, Staff } from '@/types/database'
import { Package, Plus, Pencil, Trash2 } from 'lucide-vue-next'
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
  description: ''
})
const formError = ref('')

const statusColors: Record<string, string> = {
  active: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
  maintenance: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
  inactive: 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300',
  disposed: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300'
}

const statusOptions = ['active', 'maintenance', 'inactive', 'disposed']

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
  form.value = {
    asset_name: '',
    serial_number: '',
    category_id: '',
    status: 'active',
    staff_id: '',
    purchase_date: '',
    description: ''
  }
  formError.value = ''
  showModal.value = true
}

function openEdit(asset: AssetWithRelations) {
  editingId.value = asset.id
  form.value = {
    asset_name: asset.asset_name,
    serial_number: asset.serial_number || '',
    category_id: asset.category_id || '',
    status: asset.status,
    staff_id: asset.staff_id || '',
    purchase_date: asset.purchase_date || '',
    description: asset.description || ''
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
      const { error } = await supabase
        .from('assets')
        .update(payload)
        .eq('id', editingId.value)

      if (error) throw error
    } else {
      const { error } = await supabase.from('assets').insert(payload)
      if (error) throw error
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

onMounted(fetchData)
</script>

<template>
  <div class="p-6">
    <div class="flex items-center justify-between mb-8">
      <div class="flex items-center gap-3">
        <Package class="w-8 h-8 text-primary" />
        <h1 class="text-2xl font-bold">Assets</h1>
      </div>
      <button
        @click="openCreate"
        class="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90"
      >
        <Plus class="w-4 h-4" />
        Add Asset
      </button>
    </div>

    <div v-if="loading" class="text-muted-foreground">Loading...</div>

    <div v-else-if="assets.length === 0" class="text-center py-12 text-muted-foreground">
      No assets found. Create your first asset!
    </div>

    <div v-else class="bg-card border rounded-lg overflow-hidden overflow-x-auto">
      <table class="w-full">
        <thead class="bg-muted/50">
          <tr>
            <th class="px-4 py-3 text-left text-sm font-medium">Asset Name</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Category</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Status</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Assigned To</th>
            <th class="px-4 py-3 text-left text-sm font-medium">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="asset in assets" :key="asset.id" class="hover:bg-muted/30">
            <td class="px-4 py-3">
              <div>
                <div class="font-medium">{{ asset.asset_name }}</div>
                <div class="text-sm text-muted-foreground">{{ asset.serial_number || '-' }}</div>
              </div>
            </td>
            <td class="px-4 py-3">{{ asset.categories?.name || '-' }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-1 rounded-full text-xs font-medium', statusColors[asset.status]]">
                {{ asset.status }}
              </span>
            </td>
            <td class="px-4 py-3">{{ asset.staff?.name || '-' }}</td>
            <td class="px-4 py-3">
              <div class="flex items-center gap-2">
                <button @click="openEdit(asset)" class="p-1 hover:bg-muted rounded" title="Edit">
                  <Pencil class="w-4 h-4" />
                </button>
                <button @click="deleteAsset(asset.id)" class="p-1 hover:bg-muted rounded text-red-500" title="Delete">
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
      :title="editingId ? 'Edit Asset' : 'Add Asset'"
      size="lg"
      @close="closeModal"
    >
      <form @submit.prevent="saveAsset" class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Category *</label>
            <select
              v-model="form.category_id"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <option value="">Select category</option>
              <option v-for="cat in categories" :key="cat.id" :value="cat.id">
                {{ cat.name }} ({{ cat.code }})
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Asset Name *</label>
            <input
              v-model="form.asset_name"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Auto-generated from category"
              :readonly="!editingId"
            />
            <p v-if="!editingId" class="text-xs text-muted-foreground mt-1">Auto-generated when you select a category</p>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Serial Number</label>
            <input
              v-model="form.serial_number"
              type="text"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="e.g. SN123456789"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Status</label>
            <select
              v-model="form.status"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <option v-for="status in statusOptions" :key="status" :value="status">
                {{ status.charAt(0).toUpperCase() + status.slice(1) }}
              </option>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-2">Assigned To</label>
            <select
              v-model="form.staff_id"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <option value="">Unassigned</option>
              <option v-for="staff in staffList" :key="staff.id" :value="staff.id">
                {{ staff.name }} ({{ staff.staff_id }})
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium mb-2">Purchase Date</label>
            <input
              v-model="form.purchase_date"
              type="date"
              class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Description</label>
          <textarea
            v-model="form.description"
            rows="2"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary resize-none"
            placeholder="Additional notes about this asset"
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
