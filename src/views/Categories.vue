<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Category } from '@/types/database'
import { FolderTree, Plus, Pencil, Trash2 } from 'lucide-vue-next'
import Modal from '@/components/Modal.vue'

const categories = ref<Category[]>([])
const loading = ref(true)
const saving = ref(false)

// Modal state
const showModal = ref(false)
const editingId = ref<number | null>(null)
const form = ref({ name: '', code: '', description: '' })
const formError = ref('')

function openCreate() {
  editingId.value = null
  form.value = { name: '', code: '', description: '' }
  formError.value = ''
  showModal.value = true
}

function openEdit(category: Category) {
  editingId.value = category.id
  form.value = {
    name: category.name,
    code: category.code,
    description: category.description || ''
  }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingId.value = null
  form.value = { name: '', code: '', description: '' }
  formError.value = ''
}

async function fetchCategories() {
  try {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .order('name')

    if (error) throw error
    categories.value = data || []
  } catch (error) {
    console.error('Error fetching categories:', error)
  } finally {
    loading.value = false
  }
}

async function saveCategory() {
  if (!form.value.name.trim()) {
    formError.value = 'Category name is required'
    return
  }
  if (!form.value.code.trim()) {
    formError.value = 'Category code is required'
    return
  }

  saving.value = true
  formError.value = ''

  const payload = {
    name: form.value.name.trim(),
    code: form.value.code.trim().toUpperCase(),
    description: form.value.description.trim() || null
  }

  try {
    if (editingId.value) {
      // Update
      const { error } = await supabase
        .from('categories')
        .update(payload)
        .eq('id', editingId.value)

      if (error) throw error

      // Update local state
      const index = categories.value.findIndex(c => c.id === editingId.value)
      if (index !== -1) {
        categories.value[index] = { ...categories.value[index], ...payload }
      }
    } else {
      // Create
      const { data, error } = await supabase
        .from('categories')
        .insert(payload)
        .select()
        .single()

      if (error) throw error
      categories.value.push(data)
      categories.value.sort((a, b) => a.name.localeCompare(b.name))
    }

    closeModal()
  } catch (error: any) {
    if (error.message?.includes('duplicate')) {
      formError.value = 'Category code already exists'
    } else {
      formError.value = error.message || 'Failed to save category'
    }
  } finally {
    saving.value = false
  }
}

async function deleteCategory(id: number) {
  if (!confirm('Are you sure? This will affect all assets in this category.')) return

  try {
    const { error } = await supabase.from('categories').delete().eq('id', id)
    if (error) throw error
    categories.value = categories.value.filter(c => c.id !== id)
  } catch (error) {
    console.error('Error deleting category:', error)
  }
}

onMounted(fetchCategories)
</script>

<template>
  <div class="p-6">
    <div class="flex items-center justify-between mb-8">
      <div class="flex items-center gap-3">
        <FolderTree class="w-8 h-8 text-primary" />
        <h1 class="text-2xl font-bold">Categories</h1>
      </div>
      <button
        @click="openCreate"
        class="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90"
      >
        <Plus class="w-4 h-4" />
        Add Category
      </button>
    </div>

    <div v-if="loading" class="text-muted-foreground">Loading...</div>

    <div v-else-if="categories.length === 0" class="text-center py-12 text-muted-foreground">
      No categories found. Create your first category!
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="category in categories" :key="category.id" class="bg-card border rounded-lg p-4">
        <div class="flex items-start justify-between">
          <div>
            <h3 class="font-semibold">{{ category.name }}</h3>
            <p class="text-sm text-muted-foreground mt-1">Code: {{ category.code }}</p>
            <p v-if="category.description" class="text-sm text-muted-foreground mt-2">
              {{ category.description }}
            </p>
          </div>
          <div class="flex items-center gap-1">
            <button @click="openEdit(category)" class="p-1 hover:bg-muted rounded" title="Edit">
              <Pencil class="w-4 h-4" />
            </button>
            <button @click="deleteCategory(category.id)" class="p-1 hover:bg-muted rounded text-red-500" title="Delete">
              <Trash2 class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <Modal
      :show="showModal"
      :title="editingId ? 'Edit Category' : 'Add Category'"
      @close="closeModal"
    >
      <form @submit.prevent="saveCategory" class="space-y-4">
        <div>
          <label class="block text-sm font-medium mb-2">Category Name</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            placeholder="e.g. Laptop, Desktop, Monitor"
            autofocus
          />
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Code</label>
          <input
            v-model="form.code"
            type="text"
            maxlength="10"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary uppercase"
            placeholder="e.g. LAP, DES, MON"
          />
          <p class="text-xs text-muted-foreground mt-1">Used for asset naming: KLSB-CODE-001</p>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Description (optional)</label>
          <textarea
            v-model="form.description"
            rows="2"
            class="w-full px-3 py-2 border rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-primary resize-none"
            placeholder="Brief description of this category"
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
