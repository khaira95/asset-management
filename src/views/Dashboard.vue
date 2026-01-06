<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { LayoutDashboard, Package, Users, MapPin, Key, AlertTriangle } from 'lucide-vue-next'

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
  { label: 'Total Assets', value: stats.value.totalAssets, icon: Package, color: 'bg-blue-500' },
  { label: 'Active Assets', value: stats.value.activeAssets, icon: Package, color: 'bg-green-500' },
  { label: 'Maintenance', value: stats.value.maintenanceAssets, icon: AlertTriangle, color: 'bg-yellow-500' },
  { label: 'Staff', value: stats.value.totalStaff, icon: Users, color: 'bg-purple-500' },
  { label: 'Locations', value: stats.value.totalLocations, icon: MapPin, color: 'bg-indigo-500' },
  { label: 'Licenses', value: stats.value.totalLicenses, icon: Key, color: 'bg-pink-500' },
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
  <div class="p-6">
    <div class="flex items-center gap-3 mb-8">
      <LayoutDashboard class="w-8 h-8 text-primary" />
      <h1 class="text-2xl font-bold">Dashboard</h1>
    </div>

    <div v-if="loading" class="text-muted-foreground">Loading...</div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="stat in statCards"
        :key="stat.label"
        class="bg-card border rounded-lg p-6 flex items-center gap-4"
      >
        <div :class="[stat.color, 'p-3 rounded-lg']">
          <component :is="stat.icon" class="w-6 h-6 text-white" />
        </div>
        <div>
          <p class="text-sm text-muted-foreground">{{ stat.label }}</p>
          <p class="text-2xl font-bold">{{ stat.value }}</p>
        </div>
      </div>
    </div>

    <div v-if="stats.expiringLicenses > 0" class="mt-6 p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-lg">
      <div class="flex items-center gap-2 text-yellow-600 dark:text-yellow-400">
        <AlertTriangle class="w-5 h-5" />
        <span class="font-medium">{{ stats.expiringLicenses }} license(s) expiring within 30 days</span>
      </div>
    </div>
  </div>
</template>
