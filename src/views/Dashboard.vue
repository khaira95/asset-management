<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import {
  LayoutDashboard,
  Package,
  Users,
  MapPin,
  Key,
  ArrowUpRight,
  Clock,
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

// Monthly assets data by status
interface MonthlyData {
  month: string
  year: number
  active: number
  maintenance: number
  inactive: number
  disposed: number
  total: number
}

const monthlyData = ref<MonthlyData[]>([])
const maxMonthly = computed(() => Math.max(...monthlyData.value.map(d => d.total), 1))

async function fetchMonthlyData() {
  try {
    // Get all assets with their current status and created_at
    const [assetsRes, historyRes] = await Promise.all([
      supabase.from('assets').select('id, status, created_at').order('created_at', { ascending: true }),
      supabase.from('asset_history').select('asset_id, old_value, new_value, created_at').eq('field_name', 'status').order('created_at', { ascending: true })
    ])

    if (assetsRes.error) throw assetsRes.error

    const assets = assetsRes.data || []
    const history = historyRes.data || []

    // Get last 6 months
    const months: MonthlyData[] = []
    const now = new Date()

    for (let i = 5; i >= 0; i--) {
      const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
      months.push({
        month: date.toLocaleString('en', { month: 'short' }),
        year: date.getFullYear(),
        active: 0,
        maintenance: 0,
        inactive: 0,
        disposed: 0,
        total: 0
      })
    }

    // For each month, calculate asset status at end of that month
    months.forEach((monthData, idx) => {
      const monthEnd = new Date(now.getFullYear(), now.getMonth() - (5 - idx) + 1, 0, 23, 59, 59)

      assets.forEach(asset => {
        const createdAt = new Date(asset.created_at)

        // Asset must exist by end of this month
        if (createdAt > monthEnd) return

        // Find the status at the end of this month
        // Start with 'active' (default when created) and apply history changes
        let statusAtMonth = 'active'

        // Get all history for this asset up to monthEnd
        const assetHistory = history.filter(h =>
          h.asset_id === asset.id && new Date(h.created_at) <= monthEnd
        )

        // Apply each status change in order
        assetHistory.forEach(h => {
          if (h.new_value) {
            statusAtMonth = h.new_value
          }
        })

        // If no history, use current status (for assets created before history tracking)
        if (assetHistory.length === 0) {
          statusAtMonth = asset.status
        }

        monthData.total++
        if (statusAtMonth === 'active') monthData.active++
        else if (statusAtMonth === 'maintenance') monthData.maintenance++
        else if (statusAtMonth === 'inactive') monthData.inactive++
        else if (statusAtMonth === 'disposed') monthData.disposed++
      })
    })

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
  <div class="p-4 lg:p-6">
    <!-- Header -->
    <div class="mb-4">
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center">
          <LayoutDashboard class="w-4 h-4 text-primary" />
        </div>
        <div>
          <h1 class="text-xl font-semibold text-foreground tracking-tight">Dashboard</h1>
          <p class="text-xs text-muted-foreground">Asset inventory overview</p>
        </div>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div v-for="i in 4" :key="i" class="h-28 bg-card border rounded-2xl animate-pulse" />
    </div>

    <div v-else>
      <!-- Stats grid - 4 columns -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3 stagger-children">
        <div
          v-for="stat in statCards"
          :key="stat.label"
          class="group bg-card border rounded-xl p-3 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300 cursor-default"
        >
          <div class="flex items-center justify-between mb-2">
            <div :class="['w-8 h-8 rounded-lg flex items-center justify-center', stat.iconBg]">
              <component :is="stat.icon" class="w-4 h-4 text-white" />
            </div>
            <ArrowUpRight class="w-3.5 h-3.5 text-muted-foreground/30 group-hover:text-primary transition-colors" />
          </div>
          <p class="text-xl font-semibold text-foreground tracking-tight">{{ stat.value }}</p>
          <p class="text-[11px] text-muted-foreground">{{ stat.label }}</p>
        </div>
      </div>

      <!-- Asset Status Overview - Full Width -->
      <div class="bg-card border rounded-2xl p-5 mt-4">
        <div class="flex flex-col lg:flex-row lg:items-center gap-6">
          <!-- Left: Donut Chart -->
          <div class="flex-shrink-0 flex items-center gap-4">
            <div class="relative w-28 h-28">
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
                <span class="text-2xl font-bold text-foreground">{{ stats.totalAssets }}</span>
                <span class="text-[10px] text-muted-foreground">Total</span>
              </div>
            </div>
            <div>
              <h3 class="font-semibold text-foreground">Asset Status</h3>
              <p class="text-xs text-muted-foreground">Current distribution</p>
            </div>
          </div>

          <!-- Right: Status Breakdown Cards -->
          <div class="flex-1">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div
                v-for="item in assetDistribution"
                :key="item.label"
                class="p-3 rounded-xl border bg-muted/30"
              >
                <div class="flex items-center gap-2 mb-1">
                  <div :class="['w-2.5 h-2.5 rounded-full', item.color]" />
                  <span class="text-xs text-muted-foreground">{{ item.label }}</span>
                </div>
                <p class="text-xl font-bold text-foreground">{{ item.value }}</p>
                <p class="text-[10px] text-muted-foreground">{{ item.percent }}%</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Asset Trends Chart -->
      <div class="bg-card border rounded-2xl p-5 mt-4">
        <div class="flex items-start justify-between mb-3">
          <div>
            <h3 class="font-semibold text-foreground">Asset Trends</h3>
            <p class="text-xs text-muted-foreground">Monthly status breakdown</p>
          </div>
          <!-- Legend -->
          <div class="flex flex-wrap gap-2 text-[10px]">
            <div class="flex items-center gap-1">
              <div class="w-2.5 h-2.5 rounded-sm bg-emerald-500"></div>
              <span class="text-muted-foreground">Active</span>
            </div>
            <div class="flex items-center gap-1">
              <div class="w-2.5 h-2.5 rounded-sm bg-amber-500"></div>
              <span class="text-muted-foreground">Maintenance</span>
            </div>
            <div class="flex items-center gap-1">
              <div class="w-2.5 h-2.5 rounded-sm bg-gray-400"></div>
              <span class="text-muted-foreground">Inactive</span>
            </div>
            <div class="flex items-center gap-1">
              <div class="w-2.5 h-2.5 rounded-sm bg-red-500"></div>
              <span class="text-muted-foreground">Disposed</span>
            </div>
          </div>
        </div>

        <!-- Stacked Bar Chart -->
        <div v-if="monthlyData.length === 0" class="flex items-center justify-center h-36">
          <p class="text-sm text-muted-foreground">Loading...</p>
        </div>
        <div v-else class="flex items-end justify-between gap-3 h-36">
          <div
            v-for="data in monthlyData"
            :key="`${data.month}-${data.year}`"
            class="flex-1 flex flex-col items-center gap-2"
          >
            <!-- Stacked bar -->
            <div class="w-full relative group cursor-default h-full flex flex-col justify-end">
              <!-- Tooltip -->
              <div class="absolute -top-2 left-1/2 -translate-x-1/2 -translate-y-full px-3 py-2 bg-foreground text-background text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-20 shadow-lg">
                <p class="font-semibold mb-1">{{ data.month }} {{ data.year }}</p>
                <p class="text-emerald-300">Active: {{ data.active }}</p>
                <p class="text-amber-300">Maintenance: {{ data.maintenance }}</p>
                <p class="text-gray-300">Inactive: {{ data.inactive }}</p>
                <p class="text-red-300">Disposed: {{ data.disposed }}</p>
                <p class="border-t border-white/20 mt-1 pt-1 font-medium">Total: {{ data.total }}</p>
              </div>

              <!-- Stacked segments -->
              <div
                class="w-full flex flex-col-reverse rounded-t-lg overflow-hidden transition-all duration-500"
                :style="{ height: `${(data.total / maxMonthly) * 100}%`, minHeight: data.total > 0 ? '4px' : '0' }"
              >
                <!-- Active (bottom) -->
                <div
                  v-if="data.active > 0"
                  class="w-full bg-emerald-500 group-hover:bg-emerald-400 transition-colors"
                  :style="{ height: `${(data.active / data.total) * 100}%` }"
                ></div>
                <!-- Maintenance -->
                <div
                  v-if="data.maintenance > 0"
                  class="w-full bg-amber-500 group-hover:bg-amber-400 transition-colors"
                  :style="{ height: `${(data.maintenance / data.total) * 100}%` }"
                ></div>
                <!-- Inactive -->
                <div
                  v-if="data.inactive > 0"
                  class="w-full bg-gray-400 group-hover:bg-gray-300 transition-colors"
                  :style="{ height: `${(data.inactive / data.total) * 100}%` }"
                ></div>
                <!-- Disposed (top) -->
                <div
                  v-if="data.disposed > 0"
                  class="w-full bg-red-500 group-hover:bg-red-400 transition-colors"
                  :style="{ height: `${(data.disposed / data.total) * 100}%` }"
                ></div>
              </div>
            </div>
            <!-- Labels -->
            <div class="text-center">
              <span class="text-sm font-semibold text-foreground block">{{ data.total }}</span>
              <span class="text-xs text-muted-foreground block">{{ data.month }}</span>
              <span class="text-[10px] text-muted-foreground/60">{{ data.year }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Activity - Full Width -->
      <div class="bg-card border rounded-2xl p-5 mt-4">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="font-semibold text-foreground">Recent Activity</h3>
            <p class="text-sm text-muted-foreground">Latest updates</p>
          </div>
        </div>

        <div v-if="recentActivities.length === 0" class="text-center py-6">
          <Clock class="w-6 h-6 text-muted-foreground/30 mx-auto mb-2" />
          <p class="text-sm text-muted-foreground">No recent activity yet</p>
        </div>
        <div v-else class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          <div
            v-for="(activity, index) in recentActivities"
            :key="index"
            class="flex items-center gap-3 p-3 rounded-xl bg-muted/30 hover:bg-muted/50 transition-colors"
          >
            <div :class="['w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0', activity.iconBg]">
              <component :is="activity.icon" class="w-4 h-4 text-white" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-xs font-medium text-foreground truncate">{{ activity.item }}</p>
              <p class="text-xs text-muted-foreground">{{ activity.time }}</p>
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
