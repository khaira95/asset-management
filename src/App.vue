<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
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
  X,
  ChevronRight
} from 'lucide-vue-next'

const router = useRouter()
const route = useRoute()
const user = ref<any>(null)
const sidebarOpen = ref(false)
const authReady = ref(false)
const routerReady = ref(false)

const navigation = [
  { name: 'Dashboard', to: '/dashboard', icon: LayoutDashboard },
  { name: 'Assets', to: '/assets', icon: Package },
  { name: 'Categories', to: '/categories', icon: FolderTree },
  { name: 'Staff', to: '/staff', icon: Users },
  { name: 'Locations', to: '/locations', icon: MapPin },
  { name: 'Licenses', to: '/licenses', icon: Key },
]

// Pages that should NOT show the app layout (sidebar)
const isPublicPage = computed(() => {
  return route.name === 'login' || route.name === 'landing'
})

async function handleLogout() {
  await supabase.auth.signOut()
  user.value = null
  router.push('/login')
}

onMounted(async () => {
  // Wait for router to be ready first to prevent flash
  await router.isReady()
  routerReady.value = true

  // Then check auth
  const { data: { session } } = await supabase.auth.getSession()
  user.value = session?.user || null
  authReady.value = true

  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
  })
})
</script>

<template>
  <!-- Loading state - wait for router and auth check -->
  <div v-if="!authReady || !routerReady" class="min-h-screen bg-background" />

  <!-- Public pages (login, landing) - no layout -->
  <RouterView v-else-if="isPublicPage" />

  <!-- App layout with sidebar -->
  <div v-else class="min-h-screen bg-background">
    <!-- Mobile Header -->
    <header class="lg:hidden fixed top-0 left-0 right-0 z-50 h-14 bg-card border-b flex items-center px-4 gap-3">
      <button
        @click="sidebarOpen = !sidebarOpen"
        class="p-2 -ml-2 text-foreground hover:bg-muted rounded-lg transition-colors"
      >
        <Menu v-if="!sidebarOpen" class="w-5 h-5" />
        <X v-else class="w-5 h-5" />
      </button>
      <div class="flex items-center gap-2">
        <div class="w-7 h-7 rounded-lg bg-primary flex items-center justify-center">
          <Package class="w-4 h-4 text-primary-foreground" />
        </div>
        <span class="font-semibold text-foreground text-sm">Asset Manager</span>
      </div>
    </header>

    <!-- Mobile overlay -->
    <Transition name="fade">
      <div
        v-if="sidebarOpen"
        class="lg:hidden fixed inset-0 bg-black/40 backdrop-blur-sm z-30"
        @click="sidebarOpen = false"
      />
    </Transition>

    <!-- Sidebar -->
    <aside
      :class="[
        'fixed inset-y-0 left-0 z-40 w-72 bg-sidebar transform transition-all duration-300 ease-out',
        sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      ]"
    >
      <div class="flex flex-col h-full pt-14 lg:pt-0">
        <!-- Logo -->
        <div class="p-6 pb-4">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-sidebar-accent flex items-center justify-center">
              <Package class="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 class="text-lg font-semibold text-sidebar-foreground tracking-tight">Asset Manager</h1>
              <p class="text-xs text-sidebar-foreground/50">Inventory System</p>
            </div>
          </div>
        </div>

        <!-- Navigation -->
        <nav class="flex-1 px-4 space-y-1 overflow-y-auto">
          <p class="px-3 py-2 text-[11px] font-medium text-sidebar-foreground/40 uppercase tracking-wider">Menu</p>
          <RouterLink
            v-for="item in navigation"
            :key="item.name"
            :to="item.to"
            @click="sidebarOpen = false"
            :class="[
              'group flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200',
              route.path === item.to
                ? 'bg-sidebar-accent text-white shadow-lg shadow-sidebar-accent/25'
                : 'text-sidebar-foreground/70 hover:text-sidebar-foreground hover:bg-sidebar-muted'
            ]"
          >
            <component
              :is="item.icon"
              :class="[
                'w-[18px] h-[18px] transition-transform duration-200',
                route.path === item.to ? '' : 'group-hover:scale-110'
              ]"
            />
            <span class="font-medium text-sm">{{ item.name }}</span>
            <ChevronRight
              v-if="route.path === item.to"
              class="w-4 h-4 ml-auto opacity-70"
            />
          </RouterLink>
        </nav>

        <!-- User section -->
        <div class="p-4 mx-4 mb-4 rounded-xl bg-sidebar-muted">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 rounded-lg bg-sidebar-accent/20 flex items-center justify-center">
              <span class="text-sm font-semibold text-sidebar-accent">
                {{ user?.email?.charAt(0).toUpperCase() || 'U' }}
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-sidebar-foreground truncate">
                {{ user?.email?.split('@')[0] || 'User' }}
              </p>
              <p class="text-xs text-sidebar-foreground/50 truncate">
                {{ user?.email || 'user@example.com' }}
              </p>
            </div>
            <button
              @click="handleLogout"
              class="p-2 hover:bg-sidebar-accent/10 rounded-lg transition-colors group"
              title="Sign out"
            >
              <LogOut class="w-4 h-4 text-sidebar-foreground/50 group-hover:text-sidebar-accent transition-colors" />
            </button>
          </div>
        </div>
      </div>
    </aside>

    <!-- Main content -->
    <main class="lg:pl-72 pt-14 lg:pt-0 min-h-screen">
      <div class="animate-fade-in">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
