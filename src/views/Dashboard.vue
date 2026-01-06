<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { LayoutDashboard, Package, Users, MapPin, Key, AlertTriangle, TrendingUp, ArrowUpRight } from 'lucide-vue-next'

interface Stats {
  totalAssets: number
  activeAssets: number
  maintenanceAssets: number
  totalStaff: number
  totalLocations: number
  totalLicenses: number
  expiringLicenses: number
}

const stats = ref<Stats>({
  totalAssets: 0,
  activeAssets: 0,
  maintenanceAssets: 0,
  totalStaff: 0,
  totalLocations: 0,
  totalLicenses: 0,
  expiringLicenses: 0
})

const loading = ref(true)

const statCards = computed(() => [
  {
    label: 'Total Assets',
    value: stats.value.totalAssets,
    icon: Package,
    color: 'bg-primary/10 text-primary',
    iconBg: 'bg-primary'
  },
  {
    label: 'Active',
    value: stats.value.activeAssets,
    icon: TrendingUp,
    color: 'bg-emerald-50 text-emerald-600',
    iconBg: 'bg-emerald-500'
  },
  {
    label: 'Maintenance',
    value: stats.value.maintenanceAssets,
    icon: AlertTriangle,
    color: 'bg-amber-50 text-amber-600',
    iconBg: 'bg-amber-500'
  },
  {
    label: 'Staff',
    value: stats.value.totalStaff,
    icon: Users,
    color: 'bg-violet-50 text-violet-600',
    iconBg: 'bg-violet-500'
  },
  {
    label: 'Locations',
    value: stats.value.totalLocations,
    icon: MapPin,
    color: 'bg-sky-50 text-sky-600',
    iconBg: 'bg-sky-500'
  },
  {
    label: 'Licenses',
    value: stats.value.totalLicenses,
    icon: Key,
    color: 'bg-rose-50 text-rose-600',
    iconBg: 'bg-rose-500'
  },
])

async function fetchStats() {
  try {
    const [assets, staff, locations, licenses] = await Promise.all([
      supabase.from('assets').select('status'),
      supabase.from('staff').select('id', { count: 'exact', head: true }),
      supabase.from('locations').select('id', { count: 'exact', head: true }),
      supabase.from('licenses').select('expiration_date')
    ])

    const assetData = assets.data || []
    const today = new Date()
    const thirtyDaysFromNow = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000)

    stats.value = {
      totalAssets: assetData.length,
      activeAssets: assetData.filter(a => a.status === 'active').length,
      maintenanceAssets: assetData.filter(a => a.status === 'maintenance').length,
      totalStaff: staff.count || 0,
      totalLocations: locations.count || 0,
      totalLicenses: (licenses.data || []).length,
      expiringLicenses: (licenses.data || []).filter(l => {
        if (!l.expiration_date) return false
        const expDate = new Date(l.expiration_date)
        return expDate <= thirtyDaysFromNow && expDate >= today
      }).length
    }
  } catch (error) {
    console.error('Error fetching stats:', error)
  } finally {
    loading.value = false
  }
}

onMounted(fetchStats)
</script>

<template>
  <div class="p-6 lg:p-8 max-w-7xl">
    <!-- Header -->
    <div class="mb-8">
      <div class="flex items-center gap-3 mb-2">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <LayoutDashboard class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Dashboard</h1>
          <p class="text-sm text-muted-foreground">Overview of your asset inventory</p>
        </div>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="i in 6" :key="i" class="h-32 bg-card border rounded-2xl animate-pulse" />
    </div>

    <!-- Stats grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 stagger-children">
      <div
        v-for="stat in statCards"
        :key="stat.label"
        class="group bg-card border rounded-2xl p-5 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300 cursor-default"
      >
        <div class="flex items-start justify-between">
          <div :class="['w-11 h-11 rounded-xl flex items-center justify-center', stat.iconBg]">
            <component :is="stat.icon" class="w-5 h-5 text-white" />
          </div>
          <ArrowUpRight class="w-4 h-4 text-muted-foreground/40 group-hover:text-primary group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all" />
        </div>
        <div class="mt-4">
          <p class="text-3xl font-semibold text-foreground tracking-tight">{{ stat.value }}</p>
          <p class="text-sm text-muted-foreground mt-1">{{ stat.label }}</p>
        </div>
      </div>
    </div>

    <!-- Alert -->
    <Transition name="slide">
      <div
        v-if="!loading && stats.expiringLicenses > 0"
        class="mt-6 p-4 bg-amber-50 border border-amber-200 rounded-2xl animate-slide-up"
        style="animation-delay: 400ms"
      >
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-amber-500 flex items-center justify-center flex-shrink-0">
            <AlertTriangle class="w-5 h-5 text-white" />
          </div>
          <div>
            <p class="font-medium text-amber-800">License Expiration Warning</p>
            <p class="text-sm text-amber-700 mt-0.5">
              {{ stats.expiringLicenses }} license{{ stats.expiringLicenses > 1 ? 's' : '' }} expiring within 30 days
            </p>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.slide-enter-active {
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-enter-from {
  opacity: 0;
  transform: translateY(12px);
}
</style>
