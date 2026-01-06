<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import {
  LayoutDashboard,
  Package,
  FolderTree,
  Users,
  MapPin,
  Key,
  LogOut,
  Menu,
  X
} from 'lucide-vue-next'

const router = useRouter()
const route = useRoute()
const user = ref<any>(null)
const sidebarOpen = ref(false)

const navigation = [
  { name: 'Dashboard', to: '/', icon: LayoutDashboard },
  { name: 'Assets', to: '/assets', icon: Package },
  { name: 'Categories', to: '/categories', icon: FolderTree },
  { name: 'Staff', to: '/staff', icon: Users },
  { name: 'Locations', to: '/locations', icon: MapPin },
  { name: 'Licenses', to: '/licenses', icon: Key },
]

async function handleLogout() {
  await supabase.auth.signOut()
  user.value = null
  router.push('/login')
}

onMounted(async () => {
  const { data: { session } } = await supabase.auth.getSession()
  user.value = session?.user || null

  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
  })
})
</script>

<template>
  <!-- Login page - no layout -->
  <RouterView v-if="route.name === 'login'" />

  <!-- App layout with sidebar -->
  <div v-else class="min-h-screen bg-background">
    <!-- Mobile menu button -->
    <div class="lg:hidden fixed top-4 left-4 z-50">
      <button @click="sidebarOpen = !sidebarOpen" class="p-2 bg-card border rounded-lg">
        <Menu v-if="!sidebarOpen" class="w-5 h-5" />
        <X v-else class="w-5 h-5" />
      </button>
    </div>

    <!-- Sidebar -->
    <aside
      :class="[
        'fixed inset-y-0 left-0 z-40 w-64 bg-card border-r transform transition-transform duration-200 ease-in-out',
        sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <div class="flex flex-col h-full">
        <!-- Logo -->
        <div class="p-6 border-b">
          <h1 class="text-xl font-bold">Asset Management</h1>
          <p class="text-sm text-muted-foreground">Vercel + Supabase</p>
        </div>

        <!-- Navigation -->
        <nav class="flex-1 p-4 space-y-1">
          <RouterLink
            v-for="item in navigation"
            :key="item.name"
            :to="item.to"
            @click="sidebarOpen = false"
            :class="[
              'flex items-center gap-3 px-3 py-2 rounded-lg transition-colors',
              route.path === item.to
                ? 'bg-primary text-primary-foreground'
                : 'hover:bg-muted'
            ]"
          >
            <component :is="item.icon" class="w-5 h-5" />
            {{ item.name }}
          </RouterLink>
        </nav>

        <!-- User section -->
        <div class="p-4 border-t">
          <div class="flex items-center justify-between">
            <div class="text-sm truncate">
              {{ user?.email || 'User' }}
            </div>
            <button @click="handleLogout" class="p-2 hover:bg-muted rounded-lg" title="Logout">
              <LogOut class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </aside>

    <!-- Main content -->
    <main class="lg:pl-64">
      <RouterView />
    </main>
  </div>
</template>
