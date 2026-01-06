<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import {
  LayoutDashboard,
  Package,
  Users,
  MapPin,
  Key,
  AlertTriangle,
  TrendingUp,
  ArrowUpRight,
  Clock,
  CheckCircle2,
  XCircle,
  Wrench
} from 'lucide-vue-next'

interface Stats {
  totalAssets: number
  activeAssets: number
  maintenanceAssets: number
  inactiveAssets: number
  disposedAssets: number
  totalStaff: number
  totalLocations: number
  totalLicenses: number
  expiringLicenses: number
}

const stats = ref<Stats>({
  totalAssets: 0,
  activeAssets: 0,
  maintenanceAssets: 0,
  inactiveAssets: 0,
  disposedAssets: 0,
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
    iconBg: 'bg-primary'
  },
  {
    label: 'Active',
    value: stats.value.activeAssets,
    icon: TrendingUp,
    iconBg: 'bg-emerald-500'
  },
  {
    label: 'Maintenance',
    value: stats.value.maintenanceAssets,
    icon: Wrench,
    iconBg: 'bg-amber-500'
  },
  {
    label: 'Staff',
    value: stats.value.totalStaff,
    icon: Users,
    iconBg: 'bg-violet-500'
  },
  {
    label: 'Locations',
    value: stats.value.totalLocations,
    icon: MapPin,
    iconBg: 'bg-sky-500'
  },
  {
    label: 'Licenses',
    value: stats.value.totalLicenses,
    icon: Key,
    iconBg: 'bg-rose-500'
  },
])

// Asset distribution for pie chart visualization
const assetDistribution = computed(() => {
  const total = stats.value.totalAssets || 1
  return [
    { label: 'Active', value: stats.value.activeAssets, percent: Math.round((stats.value.activeAssets / total) * 100), color: 'bg-emerald-500' },
    { label: 'Maintenance', value: stats.value.maintenanceAssets, percent: Math.round((stats.value.maintenanceAssets / total) * 100), color: 'bg-amber-500' },
    { label: 'Inactive', value: stats.value.inactiveAssets, percent: Math.round((stats.value.inactiveAssets / total) * 100), color: 'bg-gray-400' },
    { label: 'Disposed', value: stats.value.disposedAssets, percent: Math.round((stats.value.disposedAssets / total) * 100), color: 'bg-red-500' },
  ]
})

// Dummy monthly data for chart
const monthlyData = [
  { month: 'Jul', assets: 12 },
  { month: 'Aug', assets: 19 },
  { month: 'Sep', assets: 15 },
  { month: 'Oct', assets: 25 },
  { month: 'Nov', assets: 22 },
  { month: 'Dec', assets: 30 },
]

const maxMonthly = computed(() => Math.max(...monthlyData.map(d => d.assets)))

// Dummy recent activities
const recentActivities = [
  { action: 'Asset added', item: 'MacBook Pro 14"', time: '2 hours ago', icon: Package, iconBg: 'bg-emerald-500' },
  { action: 'Staff assigned', item: 'Ahmad to Dell Monitor', time: '5 hours ago', icon: Users, iconBg: 'bg-violet-500' },
  { action: 'License expiring', item: 'Adobe Creative Cloud', time: '1 day ago', icon: AlertTriangle, iconBg: 'bg-amber-500' },
  { action: 'Maintenance', item: 'HP Printer #3', time: '2 days ago', icon: Wrench, iconBg: 'bg-sky-500' },
]

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
      inactiveAssets: assetData.filter(a => a.status === 'inactive').length,
      disposedAssets: assetData.filter(a => a.status === 'disposed').length,
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
  <div class="p-6 lg:p-8">
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
    <div v-if="loading" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      <div v-for="i in 6" :key="i" class="h-28 bg-card border rounded-2xl animate-pulse" />
    </div>

    <div v-else>
      <!-- Stats grid - 6 columns on large screens -->
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 stagger-children">
        <div
          v-for="stat in statCards"
          :key="stat.label"
          class="group bg-card border rounded-2xl p-4 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300 cursor-default"
        >
          <div class="flex items-center justify-between mb-3">
            <div :class="['w-10 h-10 rounded-xl flex items-center justify-center', stat.iconBg]">
              <component :is="stat.icon" class="w-5 h-5 text-white" />
            </div>
            <ArrowUpRight class="w-4 h-4 text-muted-foreground/30 group-hover:text-primary transition-colors" />
          </div>
          <p class="text-2xl font-semibold text-foreground tracking-tight">{{ stat.value }}</p>
          <p class="text-xs text-muted-foreground mt-1">{{ stat.label }}</p>
        </div>
      </div>

      <!-- Charts Row -->
      <div class="grid lg:grid-cols-3 gap-6 mt-6">
        <!-- Asset Trend Chart -->
        <div class="lg:col-span-2 bg-card border rounded-2xl p-6">
          <h3 class="font-semibold text-foreground mb-1">Asset Growth</h3>
          <p class="text-sm text-muted-foreground mb-6">Monthly asset additions</p>

          <!-- Bar Chart -->
          <div class="flex items-end justify-between gap-3 h-48">
            <div
              v-for="data in monthlyData"
              :key="data.month"
              class="flex-1 flex flex-col items-center gap-2"
            >
              <div class="w-full bg-muted rounded-t-lg relative group cursor-default" style="min-height: 8px;">
                <div
                  class="absolute bottom-0 left-0 right-0 bg-primary rounded-t-lg transition-all duration-500 group-hover:bg-primary/80"
                  :style="{ height: `${(data.assets / maxMonthly) * 100}%`, minHeight: '8px' }"
                >
                  <div class="absolute -top-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-foreground text-background text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                    {{ data.assets }} assets
                  </div>
                </div>
              </div>
              <span class="text-xs text-muted-foreground">{{ data.month }}</span>
            </div>
          </div>
        </div>

        <!-- Asset Distribution -->
        <div class="bg-card border rounded-2xl p-6">
          <h3 class="font-semibold text-foreground mb-1">Asset Status</h3>
          <p class="text-sm text-muted-foreground mb-6">Distribution by status</p>

          <!-- Donut Chart Placeholder -->
          <div class="flex justify-center mb-6">
            <div class="relative w-36 h-36">
              <!-- Background circle -->
              <svg class="w-full h-full -rotate-90" viewBox="0 0 100 100">
                <circle
                  cx="50" cy="50" r="40"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="12"
                  class="text-muted"
                />
                <!-- Active segment -->
                <circle
                  cx="50" cy="50" r="40"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="12"
                  stroke-linecap="round"
                  class="text-emerald-500"
                  :stroke-dasharray="`${assetDistribution[0].percent * 2.51} 251`"
                />
              </svg>
              <!-- Center text -->
              <div class="absolute inset-0 flex flex-col items-center justify-center">
                <span class="text-2xl font-semibold text-foreground">{{ stats.totalAssets }}</span>
                <span class="text-xs text-muted-foreground">Total</span>
              </div>
            </div>
          </div>

          <!-- Legend -->
          <div class="space-y-2">
            <div
              v-for="item in assetDistribution"
              :key="item.label"
              class="flex items-center justify-between text-sm"
            >
              <div class="flex items-center gap-2">
                <div :class="['w-3 h-3 rounded-full', item.color]" />
                <span class="text-muted-foreground">{{ item.label }}</span>
              </div>
              <span class="font-medium text-foreground">{{ item.value }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom Row -->
      <div class="grid lg:grid-cols-2 gap-6 mt-6">
        <!-- Recent Activity -->
        <div class="bg-card border rounded-2xl p-6">
          <h3 class="font-semibold text-foreground mb-1">Recent Activity</h3>
          <p class="text-sm text-muted-foreground mb-4">Latest updates in your inventory</p>

          <div class="space-y-4">
            <div
              v-for="(activity, index) in recentActivities"
              :key="index"
              class="flex items-center gap-4 p-3 rounded-xl hover:bg-muted/50 transition-colors"
            >
              <div :class="['w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0', activity.iconBg]">
                <component :is="activity.icon" class="w-5 h-5 text-white" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-foreground">{{ activity.action }}</p>
                <p class="text-sm text-muted-foreground truncate">{{ activity.item }}</p>
              </div>
              <div class="flex items-center gap-1 text-xs text-muted-foreground">
                <Clock class="w-3 h-3" />
                {{ activity.time }}
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Stats / Alerts -->
        <div class="bg-card border rounded-2xl p-6">
          <h3 class="font-semibold text-foreground mb-1">Quick Overview</h3>
          <p class="text-sm text-muted-foreground mb-4">Key metrics at a glance</p>

          <div class="space-y-4">
            <!-- Asset Health -->
            <div class="p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
              <div class="flex items-center gap-3">
                <CheckCircle2 class="w-5 h-5 text-emerald-600" />
                <div>
                  <p class="font-medium text-emerald-800">Asset Health</p>
                  <p class="text-sm text-emerald-700">
                    {{ stats.totalAssets > 0 ? Math.round((stats.activeAssets / stats.totalAssets) * 100) : 0 }}% of assets are active
                  </p>
                </div>
              </div>
            </div>

            <!-- License Warning -->
            <div v-if="stats.expiringLicenses > 0" class="p-4 bg-amber-50 border border-amber-200 rounded-xl">
              <div class="flex items-center gap-3">
                <AlertTriangle class="w-5 h-5 text-amber-600" />
                <div>
                  <p class="font-medium text-amber-800">License Alert</p>
                  <p class="text-sm text-amber-700">{{ stats.expiringLicenses }} license(s) expiring soon</p>
                </div>
              </div>
            </div>

            <!-- Maintenance -->
            <div v-if="stats.maintenanceAssets > 0" class="p-4 bg-sky-50 border border-sky-200 rounded-xl">
              <div class="flex items-center gap-3">
                <Wrench class="w-5 h-5 text-sky-600" />
                <div>
                  <p class="font-medium text-sky-800">Under Maintenance</p>
                  <p class="text-sm text-sky-700">{{ stats.maintenanceAssets }} asset(s) being serviced</p>
                </div>
              </div>
            </div>

            <!-- All Good -->
            <div v-if="stats.expiringLicenses === 0 && stats.maintenanceAssets === 0" class="p-4 bg-muted/50 border rounded-xl">
              <div class="flex items-center gap-3">
                <CheckCircle2 class="w-5 h-5 text-muted-foreground" />
                <div>
                  <p class="font-medium text-foreground">All Clear</p>
                  <p class="text-sm text-muted-foreground">No pending alerts or issues</p>
                </div>
              </div>
            </div>

            <!-- Utilization -->
            <div class="p-4 border rounded-xl">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm text-muted-foreground">Staff Coverage</span>
                <span class="text-sm font-medium text-foreground">{{ stats.totalStaff }} staff</span>
              </div>
              <div class="h-2 bg-muted rounded-full overflow-hidden">
                <div
                  class="h-full bg-violet-500 rounded-full transition-all duration-500"
                  :style="{ width: `${Math.min((stats.totalStaff / 10) * 100, 100)}%` }"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.stagger-children > *:nth-child(1) { animation-delay: 0ms; }
.stagger-children > *:nth-child(2) { animation-delay: 50ms; }
.stagger-children > *:nth-child(3) { animation-delay: 100ms; }
.stagger-children > *:nth-child(4) { animation-delay: 150ms; }
.stagger-children > *:nth-child(5) { animation-delay: 200ms; }
.stagger-children > *:nth-child(6) { animation-delay: 250ms; }
</style>
