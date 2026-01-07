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

// License stats
interface LicenseStats {
  active: number
  expiringSoon: number
  expired: number
  seatsUsed: number
  seatsTotal: number
}

const licenseStats = ref<LicenseStats>({
  active: 0,
  expiringSoon: 0,
  expired: 0,
  seatsUsed: 0,
  seatsTotal: 0
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
// Use total assets as max for bar height scaling
const maxMonthly = computed(() => {
  if (monthlyData.value.length === 0) return 1
  return Math.max(...monthlyData.value.map(d => d.total), 1)
})

async function fetchMonthlyData() {
  try {
    // Get all assets and status change history with effective_date
    const [assetsRes, historyRes] = await Promise.all([
      supabase.from('assets').select('id, status, created_at').order('created_at', { ascending: true }),
      supabase.from('asset_history')
        .select('asset_id, new_value, effective_date, created_at')
        .eq('field_name', 'status')
    ])

    if (assetsRes.error) throw assetsRes.error
    if (historyRes.error) {
      console.warn('History query error:', historyRes.error)
    }

    const assets = assetsRes.data || []
    const history = historyRes.data || []

    console.log('Assets count:', assets.length, 'History count:', history.length)

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

    // Helper to parse date string
    const parseDate = (dateStr: string) => {
      if (!dateStr) return null
      // Handle YYYY-MM-DD format
      if (dateStr.length === 10) {
        return new Date(dateStr + 'T12:00:00')
      }
      return new Date(dateStr)
    }

    // For each month, calculate asset status based on effective_date
    months.forEach((monthData, idx) => {
      const monthEnd = new Date(now.getFullYear(), now.getMonth() - (5 - idx) + 1, 0, 23, 59, 59)

      assets.forEach(asset => {
        // Get all status changes for this asset up to monthEnd
        const assetHistory = history.filter(h => {
          if (h.asset_id !== asset.id) return false
          const changeDate = h.effective_date ? parseDate(h.effective_date) : parseDate(h.created_at)
          return changeDate && changeDate <= monthEnd
        })

        // Check if asset existed by this month
        // Asset exists if: created_at <= monthEnd OR has history with effective_date <= monthEnd
        const createdAt = new Date(asset.created_at)
        const hasHistoryInMonth = assetHistory.length > 0

        if (createdAt > monthEnd && !hasHistoryInMonth) {
          // Asset didn't exist yet and no history for this period
          return
        }

        // Find status at end of this month based on effective_date
        let statusAtMonth = 'active' // Default when created

        // Sort by effective_date to get the latest status at monthEnd
        assetHistory.sort((a, b) => {
          const dateA = a.effective_date ? parseDate(a.effective_date) : parseDate(a.created_at)
          const dateB = b.effective_date ? parseDate(b.effective_date) : parseDate(b.created_at)
          return (dateA?.getTime() || 0) - (dateB?.getTime() || 0)
        })

        // Apply status changes in order - last one is the status at monthEnd
        if (assetHistory.length > 0) {
          const lastChange = assetHistory[assetHistory.length - 1]
          if (lastChange.new_value) {
            statusAtMonth = lastChange.new_value
          }
        } else {
          // No history for this month, use current status
          statusAtMonth = asset.status
        }

        monthData.total++
        if (statusAtMonth === 'active') monthData.active++
        else if (statusAtMonth === 'maintenance') monthData.maintenance++
        else if (statusAtMonth === 'inactive') monthData.inactive++
        else if (statusAtMonth === 'disposed') monthData.disposed++
      })
    })

    console.log('Monthly data result:', months)
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

// Group activities by date
const activitiesByDate = computed(() => {
  const groups: { date: string; label: string; activities: Activity[] }[] = []
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)

  recentActivities.value.forEach(activity => {
    const activityDate = new Date(activity.timestamp)
    activityDate.setHours(0, 0, 0, 0)

    let label = ''
    const dateKey = activityDate.toISOString().split('T')[0]

    if (activityDate.getTime() === today.getTime()) {
      label = 'Hari Ini'
    } else if (activityDate.getTime() === yesterday.getTime()) {
      label = 'Semalam'
    } else {
      label = activityDate.toLocaleDateString('en-MY', { day: '2-digit', month: 'short', year: 'numeric' })
    }

    let group = groups.find(g => g.date === dateKey)
    if (!group) {
      group = { date: dateKey, label, activities: [] }
      groups.push(group)
    }
    group.activities.push(activity)
  })

  return groups.sort((a, b) => b.date.localeCompare(a.date))
})

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
      supabase.from('assets').select('asset_name, created_at, status').order('created_at', { ascending: false }).limit(10),
      supabase.from('staff').select('name, created_at').order('created_at', { ascending: false }).limit(10),
      supabase.from('locations').select('name, created_at').order('created_at', { ascending: false }).limit(5),
      supabase.from('categories').select('name, created_at').order('created_at', { ascending: false }).limit(5),
      supabase.from('licenses').select('name, created_at, expiration_date').order('created_at', { ascending: false }).limit(5)
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

    // Sort by timestamp (newest first) and take top 20
    activities.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime())
    recentActivities.value = activities.slice(0, 20)
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
      supabase.from('licenses').select('expiration_date, seats_used, seats_total')
    ])

    const assetData = assets.data || []
    const licenseData = licenses.data || []
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const thirtyDaysFromNow = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000)

    stats.value = {
      totalAssets: assetData.length,
      activeAssets: assetData.filter(a => a.status === 'active').length,
      maintenanceAssets: assetData.filter(a => a.status === 'maintenance').length,
      inactiveAssets: assetData.filter(a => a.status === 'inactive').length,
      disposedAssets: assetData.filter(a => a.status === 'disposed').length,
      totalStaff: staff.count || 0,
      totalLocations: locations.count || 0,
      totalLicenses: licenseData.length,
      expiringLicenses: licenseData.filter(l => {
        if (!l.expiration_date) return false
        const expDate = new Date(l.expiration_date)
        return expDate <= thirtyDaysFromNow && expDate >= today
      }).length
    }

    // Calculate license stats
    let active = 0
    let expiringSoon = 0
    let expired = 0
    let seatsUsed = 0
    let seatsTotal = 0

    licenseData.forEach(l => {
      seatsUsed += l.seats_used || 0
      seatsTotal += l.seats_total || 0

      if (!l.expiration_date) {
        active++ // No expiration = active
      } else {
        const expDate = new Date(l.expiration_date)
        if (expDate < today) {
          expired++
        } else if (expDate <= thirtyDaysFromNow) {
          expiringSoon++
        } else {
          active++
        }
      }
    })

    licenseStats.value = {
      active,
      expiringSoon,
      expired,
      seatsUsed,
      seatsTotal
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
  <div class="p-6 lg:p-8 min-h-screen">
    <!-- Header -->
    <div class="mb-6">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <LayoutDashboard class="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Dashboard</h1>
          <p class="text-sm text-muted-foreground">Asset inventory overview</p>
        </div>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div v-for="i in 4" :key="i" class="h-28 bg-card border rounded-2xl animate-pulse" />
    </div>

    <div v-else class="space-y-6">
      <!-- Stats grid - 4 columns -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 stagger-children">
        <div
          v-for="stat in statCards"
          :key="stat.label"
          class="group bg-card border rounded-xl p-4 hover:shadow-lg hover:shadow-black/5 hover:-translate-y-0.5 transition-all duration-300 cursor-default"
        >
          <div class="flex items-center justify-between mb-3">
            <div :class="['w-10 h-10 rounded-xl flex items-center justify-center', stat.iconBg]">
              <component :is="stat.icon" class="w-5 h-5 text-white" />
            </div>
            <ArrowUpRight class="w-4 h-4 text-muted-foreground/30 group-hover:text-primary transition-colors" />
          </div>
          <p class="text-2xl font-semibold text-foreground tracking-tight">{{ stat.value }}</p>
          <p class="text-sm text-muted-foreground">{{ stat.label }}</p>
        </div>
      </div>

      <!-- Asset Trends + Recent Activity Row -->
      <div class="grid lg:grid-cols-5 gap-6">
        <!-- Asset Trends Chart -->
        <div class="lg:col-span-3 bg-card border rounded-xl p-5">
          <div class="flex items-start justify-between mb-4">
            <div>
              <h3 class="font-semibold text-foreground">Asset Trends</h3>
              <p class="text-xs text-muted-foreground">Last 6 months</p>
            </div>
          </div>
          <!-- Legend -->
          <div class="flex flex-wrap items-center gap-3 text-xs mb-4">
            <div class="flex items-center gap-1.5">
              <div class="w-2.5 h-2.5 rounded-full bg-emerald-500"></div>
              <span class="text-muted-foreground">Active</span>
            </div>
            <div class="flex items-center gap-1.5">
              <div class="w-2.5 h-2.5 rounded-full bg-amber-500"></div>
              <span class="text-muted-foreground">Maintenance</span>
            </div>
            <div class="flex items-center gap-1.5">
              <div class="w-2.5 h-2.5 rounded-full bg-gray-400"></div>
              <span class="text-muted-foreground">Inactive</span>
            </div>
            <div class="flex items-center gap-1.5">
              <div class="w-2.5 h-2.5 rounded-full bg-red-500"></div>
              <span class="text-muted-foreground">Disposed</span>
            </div>
          </div>

          <!-- Clustered Column Chart -->
          <div v-if="monthlyData.length === 0" class="flex items-center justify-center h-48">
            <p class="text-sm text-muted-foreground">Loading...</p>
          </div>
          <div v-else class="h-48">
            <div class="flex items-end justify-around h-full gap-3 px-2">
              <div
                v-for="data in monthlyData"
                :key="`${data.month}-${data.year}`"
                class="flex-1 flex flex-col h-full"
              >
                <!-- Total badge on top -->
                <div class="text-center mb-1">
                  <span v-if="data.total > 0" class="inline-flex items-center justify-center px-1.5 py-0.5 text-[10px] font-semibold bg-primary/10 text-primary rounded-full">
                    {{ data.total }}
                  </span>
                </div>
                <!-- Clustered bars -->
                <div class="flex-1 flex items-end justify-center gap-1">
                  <div
                    class="w-4 bg-emerald-500 rounded-t transition-all duration-500"
                    :style="{ height: `${maxMonthly > 0 ? (data.active / maxMonthly) * 100 : 0}%`, minHeight: data.active > 0 ? '4px' : '0' }"
                    :title="`Active: ${data.active}`"
                  ></div>
                  <div
                    class="w-4 bg-amber-500 rounded-t transition-all duration-500"
                    :style="{ height: `${maxMonthly > 0 ? (data.maintenance / maxMonthly) * 100 : 0}%`, minHeight: data.maintenance > 0 ? '4px' : '0' }"
                    :title="`Maintenance: ${data.maintenance}`"
                  ></div>
                  <div
                    class="w-4 bg-gray-400 rounded-t transition-all duration-500"
                    :style="{ height: `${maxMonthly > 0 ? (data.inactive / maxMonthly) * 100 : 0}%`, minHeight: data.inactive > 0 ? '4px' : '0' }"
                    :title="`Inactive: ${data.inactive}`"
                  ></div>
                  <div
                    class="w-4 bg-red-500 rounded-t transition-all duration-500"
                    :style="{ height: `${maxMonthly > 0 ? (data.disposed / maxMonthly) * 100 : 0}%`, minHeight: data.disposed > 0 ? '4px' : '0' }"
                    :title="`Disposed: ${data.disposed}`"
                  ></div>
                </div>
                <!-- Month Labels -->
                <div class="text-center pt-2 mt-1 border-t border-border/50">
                  <span class="text-xs text-muted-foreground">{{ data.month }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Recent Activity -->
        <div class="lg:col-span-2 bg-card border rounded-xl p-5">
          <div class="mb-3">
            <h3 class="font-semibold text-foreground">Recent Activity</h3>
            <p class="text-xs text-muted-foreground">Latest updates</p>
          </div>

          <div v-if="recentActivities.length === 0" class="text-center py-6">
            <Clock class="w-6 h-6 text-muted-foreground/30 mx-auto mb-2" />
            <p class="text-sm text-muted-foreground">No recent activity</p>
          </div>
          <div v-else class="max-h-52 overflow-y-auto space-y-3 pr-2">
            <div v-for="group in activitiesByDate" :key="group.date">
              <div class="sticky top-0 bg-card py-1 mb-2">
                <span class="text-xs font-semibold text-primary">{{ group.label }}</span>
              </div>
              <div class="space-y-1.5">
                <div
                  v-for="(activity, index) in group.activities"
                  :key="index"
                  class="flex items-center gap-2"
                >
                  <div :class="['w-6 h-6 rounded-md flex items-center justify-center flex-shrink-0', activity.iconBg]">
                    <component :is="activity.icon" class="w-3 h-3 text-white" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-xs font-medium text-foreground truncate">{{ activity.item }}</p>
                  </div>
                  <span class="text-[10px] text-muted-foreground">{{ activity.time }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Asset Status + License Status Row -->
      <div class="grid lg:grid-cols-2 gap-6">
        <!-- Asset Status -->
        <div class="bg-card border rounded-xl p-5">
          <div class="flex items-center justify-between mb-5">
            <div>
              <h3 class="font-semibold text-foreground">Asset Status</h3>
              <p class="text-xs text-muted-foreground">Current distribution</p>
            </div>
            <div class="text-right">
              <span class="text-2xl font-bold text-foreground">{{ stats.totalAssets }}</span>
              <p class="text-xs text-muted-foreground">Total Assets</p>
            </div>
          </div>

          <!-- Status cards -->
          <div class="grid grid-cols-2 gap-3">
            <div class="p-3 rounded-xl bg-emerald-50 border border-emerald-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-emerald-500"></div>
                  <span class="text-sm text-emerald-700">Active</span>
                </div>
                <span class="text-lg font-bold text-emerald-600">{{ stats.activeAssets }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-emerald-100 rounded-full overflow-hidden">
                <div class="h-full bg-emerald-500 rounded-full transition-all duration-500" :style="{ width: `${stats.totalAssets ? (stats.activeAssets / stats.totalAssets) * 100 : 0}%` }"></div>
              </div>
            </div>

            <div class="p-3 rounded-xl bg-amber-50 border border-amber-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-amber-500"></div>
                  <span class="text-sm text-amber-700">Maintenance</span>
                </div>
                <span class="text-lg font-bold text-amber-600">{{ stats.maintenanceAssets }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-amber-100 rounded-full overflow-hidden">
                <div class="h-full bg-amber-500 rounded-full transition-all duration-500" :style="{ width: `${stats.totalAssets ? (stats.maintenanceAssets / stats.totalAssets) * 100 : 0}%` }"></div>
              </div>
            </div>

            <div class="p-3 rounded-xl bg-gray-50 border border-gray-200">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-gray-400"></div>
                  <span class="text-sm text-gray-600">Inactive</span>
                </div>
                <span class="text-lg font-bold text-gray-600">{{ stats.inactiveAssets }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                <div class="h-full bg-gray-400 rounded-full transition-all duration-500" :style="{ width: `${stats.totalAssets ? (stats.inactiveAssets / stats.totalAssets) * 100 : 0}%` }"></div>
              </div>
            </div>

            <div class="p-3 rounded-xl bg-red-50 border border-red-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-red-500"></div>
                  <span class="text-sm text-red-700">Disposed</span>
                </div>
                <span class="text-lg font-bold text-red-600">{{ stats.disposedAssets }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-red-100 rounded-full overflow-hidden">
                <div class="h-full bg-red-500 rounded-full transition-all duration-500" :style="{ width: `${stats.totalAssets ? (stats.disposedAssets / stats.totalAssets) * 100 : 0}%` }"></div>
              </div>
            </div>
          </div>
        </div>

        <!-- License Status -->
        <div class="bg-card border rounded-xl p-5">
          <div class="flex items-center justify-between mb-5">
            <div>
              <h3 class="font-semibold text-foreground">License Status</h3>
              <p class="text-xs text-muted-foreground">Software licenses</p>
            </div>
            <div class="text-right">
              <span class="text-2xl font-bold text-foreground">{{ stats.totalLicenses }}</span>
              <p class="text-xs text-muted-foreground">Total Licenses</p>
            </div>
          </div>

          <!-- License status cards -->
          <div class="grid grid-cols-2 gap-3">
            <div class="p-3 rounded-xl bg-emerald-50 border border-emerald-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-emerald-500"></div>
                  <span class="text-sm text-emerald-700">Active</span>
                </div>
                <span class="text-lg font-bold text-emerald-600">{{ licenseStats.active }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-emerald-100 rounded-full overflow-hidden">
                <div class="h-full bg-emerald-500 rounded-full transition-all duration-500" :style="{ width: `${stats.totalLicenses ? (licenseStats.active / stats.totalLicenses) * 100 : 0}%` }"></div>
              </div>
            </div>

            <div class="p-3 rounded-xl bg-amber-50 border border-amber-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-amber-500"></div>
                  <span class="text-sm text-amber-700">Expiring Soon</span>
                </div>
                <span class="text-lg font-bold text-amber-600">{{ licenseStats.expiringSoon }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-amber-100 rounded-full overflow-hidden">
                <div class="h-full bg-amber-500 rounded-full transition-all duration-500" :style="{ width: `${stats.totalLicenses ? (licenseStats.expiringSoon / stats.totalLicenses) * 100 : 0}%` }"></div>
              </div>
            </div>

            <div class="p-3 rounded-xl bg-red-50 border border-red-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-red-500"></div>
                  <span class="text-sm text-red-700">Expired</span>
                </div>
                <span class="text-lg font-bold text-red-600">{{ licenseStats.expired }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-red-100 rounded-full overflow-hidden">
                <div class="h-full bg-red-500 rounded-full transition-all duration-500" :style="{ width: `${stats.totalLicenses ? (licenseStats.expired / stats.totalLicenses) * 100 : 0}%` }"></div>
              </div>
            </div>

            <div class="p-3 rounded-xl bg-sky-50 border border-sky-100">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-sky-500"></div>
                  <span class="text-sm text-sky-700">Seats Used</span>
                </div>
                <span class="text-lg font-bold text-sky-600">{{ licenseStats.seatsUsed }}/{{ licenseStats.seatsTotal }}</span>
              </div>
              <div class="mt-2 h-1.5 bg-sky-100 rounded-full overflow-hidden">
                <div class="h-full bg-sky-500 rounded-full transition-all duration-500" :style="{ width: `${licenseStats.seatsTotal ? (licenseStats.seatsUsed / licenseStats.seatsTotal) * 100 : 0}%` }"></div>
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
