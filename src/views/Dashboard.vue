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
  Wrench,
  FolderTree
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

// Monthly active assets data
interface MonthlyData {
  month: string
  year: number
  active: number
  total: number
}

const monthlyData = ref<MonthlyData[]>([])
const maxMonthly = computed(() => Math.max(...monthlyData.value.map(d => d.active), 1))

async function fetchMonthlyData() {
  try {
    // Get all assets with their status and created_at
    const { data, error } = await supabase
      .from('assets')
      .select('status, created_at')
      .order('created_at', { ascending: true })

    if (error) throw error

    // Get last 6 months
    const months: MonthlyData[] = []
    const now = new Date()

    for (let i = 5; i >= 0; i--) {
      const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
      months.push({
        month: date.toLocaleString('en', { month: 'short' }),
        year: date.getFullYear(),
        active: 0,
        total: 0
      })
    }

    // Count active assets for each month
    // An asset counts as active in a month if it was created before/during that month and status is 'active'
    if (data) {
      months.forEach((monthData, idx) => {
        const monthStart = new Date(now.getFullYear(), now.getMonth() - (5 - idx), 1)
        const monthEnd = new Date(now.getFullYear(), now.getMonth() - (5 - idx) + 1, 0, 23, 59, 59)

        data.forEach(asset => {
          const createdAt = new Date(asset.created_at)
          // Asset exists by end of this month
          if (createdAt <= monthEnd) {
            monthData.total++
            if (asset.status === 'active') {
              monthData.active++
            }
          }
        })
      })
    }

    monthlyData.value = months
  } catch (error) {
    console.error('Error fetching monthly data:', error)
  }
}

// Recent activities from database
interface Activity {
  action: string
  item: string
  time: string
  icon: any
  iconBg: string
  timestamp: Date
}

const recentActivities = ref<Activity[]>([])

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

async function fetchRecentActivities() {
  try {
    const [assetsRes, staffRes, locationsRes, categoriesRes, licensesRes] = await Promise.all([
      supabase.from('assets').select('asset_name, created_at, status').order('created_at', { ascending: false }).limit(5),
      supabase.from('staff').select('name, created_at').order('created_at', { ascending: false }).limit(3),
      supabase.from('locations').select('name, created_at').order('created_at', { ascending: false }).limit(3),
      supabase.from('categories').select('name, created_at').order('created_at', { ascending: false }).limit(3),
      supabase.from('licenses').select('name, created_at, expiration_date').order('created_at', { ascending: false }).limit(3)
    ])

    const activities: Activity[] = []

    // Assets
    if (assetsRes.data) {
      assetsRes.data.forEach(a => {
        activities.push({
          action: 'Asset added',
          item: a.asset_name,
          time: formatTimeAgo(new Date(a.created_at)),
          icon: Package,
          iconBg: 'bg-emerald-500',
          timestamp: new Date(a.created_at)
        })
      })
    }

    // Staff
    if (staffRes.data) {
      staffRes.data.forEach(s => {
        activities.push({
          action: 'Staff added',
          item: s.name,
          time: formatTimeAgo(new Date(s.created_at)),
          icon: Users,
          iconBg: 'bg-violet-500',
          timestamp: new Date(s.created_at)
        })
      })
    }

    // Locations
    if (locationsRes.data) {
      locationsRes.data.forEach(l => {
        activities.push({
          action: 'Location added',
          item: l.name,
          time: formatTimeAgo(new Date(l.created_at)),
          icon: MapPin,
          iconBg: 'bg-sky-500',
          timestamp: new Date(l.created_at)
        })
      })
    }

    // Categories
    if (categoriesRes.data) {
      categoriesRes.data.forEach(c => {
        activities.push({
          action: 'Category added',
          item: c.name,
          time: formatTimeAgo(new Date(c.created_at)),
          icon: FolderTree,
          iconBg: 'bg-amber-500',
          timestamp: new Date(c.created_at)
        })
      })
    }

    // Licenses
    if (licensesRes.data) {
      licensesRes.data.forEach(l => {
        activities.push({
          action: 'License added',
          item: l.name,
          time: formatTimeAgo(new Date(l.created_at)),
          icon: Key,
          iconBg: 'bg-rose-500',
          timestamp: new Date(l.created_at)
        })
      })
    }

    // Sort by timestamp (newest first) and take top 6
    activities.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime())
    recentActivities.value = activities.slice(0, 6)
  } catch (error) {
    console.error('Error fetching recent activities:', error)
  }
}

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

onMounted(() => {
  fetchStats()
  fetchRecentActivities()
  fetchMonthlyData()
})
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
        <!-- Active Assets Trend Chart -->
        <div class="lg:col-span-2 bg-card border rounded-2xl p-6">
          <h3 class="font-semibold text-foreground mb-1">Active Assets Trend</h3>
          <p class="text-sm text-muted-foreground mb-6">Total active assets per month</p>

          <!-- Bar Chart -->
          <div v-if="monthlyData.length === 0" class="flex items-center justify-center h-48">
            <p class="text-sm text-muted-foreground">Loading...</p>
          </div>
          <div v-else class="flex items-end justify-between gap-3 h-48">
            <div
              v-for="data in monthlyData"
              :key="`${data.month}-${data.year}`"
              class="flex-1 flex flex-col items-center gap-2"
            >
              <div class="w-full bg-muted rounded-t-lg relative group cursor-default h-full">
                <div
                  class="absolute bottom-0 left-0 right-0 bg-emerald-500 rounded-t-lg transition-all duration-500 group-hover:bg-emerald-400"
                  :style="{ height: `${(data.active / maxMonthly) * 100}%`, minHeight: data.active > 0 ? '8px' : '0' }"
                >
                  <div class="absolute -top-10 left-1/2 -translate-x-1/2 px-2 py-1 bg-foreground text-background text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10">
                    {{ data.active }} active
                  </div>
                </div>
              </div>
              <div class="text-center">
                <span class="text-xs text-muted-foreground block">{{ data.month }}</span>
                <span class="text-[10px] text-muted-foreground/60">{{ data.year }}</span>
              </div>
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

          <div v-if="recentActivities.length === 0" class="text-center py-8">
            <Clock class="w-8 h-8 text-muted-foreground/30 mx-auto mb-2" />
            <p class="text-sm text-muted-foreground">No recent activity yet</p>
          </div>
          <div v-else class="space-y-4">
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
