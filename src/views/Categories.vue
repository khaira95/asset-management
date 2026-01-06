<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { Category } from '@/types/database'
import { FolderTree, Plus, Pencil, Trash2, Hash } from 'lucide-vue-next'
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
  <div class="p-6 lg:p-8">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <FolderTree class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Categories</h1>
          <p class="text-sm text-muted-foreground">Organize assets by type</p>
        </div>
      </div>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 active:scale-[0.98] transition-all shadow-lg shadow-primary/20"
      >
        <Plus class="w-4 h-4" />
        Add Category
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="i in 6" :key="i" class="h-32 bg-card border rounded-2xl animate-pulse" />
    </div>

    <!-- Empty state -->
    <div v-else-if="categories.length === 0" class="bg-card border rounded-2xl p-12 text-center">
      <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto mb-4">
        <FolderTree class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-semibold text-foreground mb-2">No categories yet</h3>
      <p class="text-muted-foreground mb-6">Create categories to organize your assets</p>
      <button
        @click="openCreate"
        class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 transition-all"
      >
        <Plus class="w-4 h-4" />
        Add Category
      </button>
    </div>

    <!-- Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 stagger-children">
      <div
        v-for="category in categories"
        :key="category.id"
        class="group bg-card border rounded-2xl p-5 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-2">
              <span class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-primary/10 text-primary text-xs font-medium rounded-lg">
                <Hash class="w-3 h-3" />
                {{ category.code }}
              </span>
            </div>
            <h3 class="font-semibold text-foreground text-lg">{{ category.name }}</h3>
            <p v-if="category.description" class="text-sm text-muted-foreground mt-2 line-clamp-2">
              {{ category.description }}
            </p>
            <p v-else class="text-sm text-muted-foreground/50 mt-2 italic">No description</p>
          </div>
          <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity ml-4">
            <button
              @click="openEdit(category)"
              class="p-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-lg transition-all"
              title="Edit"
            >
              <Pencil class="w-4 h-4" />
            </button>
            <button
              @click="deleteCategory(category.id)"
              class="p-2 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-lg transition-all"
              title="Delete"
            >
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
      <form @submit.prevent="saveCategory" class="space-y-5">
        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">Category Name *</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            placeholder="e.g. Laptop, Desktop, Monitor"
            autofocus
          />
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">Code *</label>
          <input
            v-model="form.code"
            type="text"
            maxlength="10"
            class="w-full h-11 px-4 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all uppercase"
            placeholder="e.g. LAP, DES, MON"
          />
          <p class="text-xs text-muted-foreground">Used for asset naming: KLSB-CODE-001</p>
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-foreground">Description</label>
          <textarea
            v-model="form.description"
            rows="2"
            class="w-full px-4 py-3 bg-background border rounded-xl text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all resize-none"
            placeholder="Brief description (optional)"
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
