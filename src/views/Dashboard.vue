<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import {
  LayoutDashboard,
  Package,
  Users,
  MapPin,
  Key,
  ArrowUpRight,
  Clock,
  FolderTree,
  TrendingUp,
  Activity,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  Trash2
} from 'lucide-vue-next'

const router = useRouter()

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
    gradient: 'from-blue-500 to-blue-600',
    bgLight: 'bg-blue-50',
    route: '/assets'
  },
  {
    label: 'Staff Members',
    value: stats.value.totalStaff,
    icon: Users,
    gradient: 'from-violet-500 to-violet-600',
    bgLight: 'bg-violet-50',
    route: '/staff'
  },
  {
    label: 'Locations',
    value: stats.value.totalLocations,
    icon: MapPin,
    gradient: 'from-cyan-500 to-cyan-600',
    bgLight: 'bg-cyan-50',
    route: '/locations'
  },
  {
    label: 'Licenses',
    value: stats.value.totalLicenses,
    icon: Key,
    gradient: 'from-rose-500 to-rose-600',
    bgLight: 'bg-rose-50',
    route: '/licenses'
  },
])

function navigateTo(route: string) {
  router.push(route)
}

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
const maxMonthly = computed(() => {
  if (monthlyData.value.length === 0) return 1
  return Math.max(...monthlyData.value.map(d => d.total), 1)
})

async function fetchMonthlyData() {
  try {
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

    const parseDate = (dateStr: string) => {
      if (!dateStr) return null
      if (dateStr.length === 10) {
        return new Date(dateStr + 'T12:00:00')
      }
      return new Date(dateStr)
    }

    months.forEach((monthData, idx) => {
      const monthEnd = new Date(now.getFullYear(), now.getMonth() - (5 - idx) + 1, 0, 23, 59, 59)

      assets.forEach(asset => {
        const assetHistory = history.filter(h => {
          if (h.asset_id !== asset.id) return false
          const changeDate = h.effective_date ? parseDate(h.effective_date) : parseDate(h.created_at)
          return changeDate && changeDate <= monthEnd
        })

        const createdAt = new Date(asset.created_at)
        const hasHistoryInMonth = assetHistory.length > 0

        if (createdAt > monthEnd && !hasHistoryInMonth) {
          return
        }

        let statusAtMonth = 'active'

        assetHistory.sort((a, b) => {
          const dateA = a.effective_date ? parseDate(a.effective_date) : parseDate(a.created_at)
          const dateB = b.effective_date ? parseDate(b.effective_date) : parseDate(b.created_at)
          return (dateA?.getTime() || 0) - (dateB?.getTime() || 0)
        })

        if (assetHistory.length > 0) {
          const lastChange = assetHistory[assetHistory.length - 1]
          if (lastChange.new_value) {
            statusAtMonth = lastChange.new_value
          }
        } else {
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

// Recent activities
interface Activity {
  action: string
  item: string
  time: string
  icon: any
  iconBg: string
  timestamp: Date
}

const recentActivities = ref<Activity[]>([])

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
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffHours < 24) return `${diffHours}h ago`
  if (diffDays < 7) return `${diffDays}d ago`
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

    if (assetsRes.data) {
      assetsRes.data.forEach(a => {
        activities.push({
          action: 'Asset added',
          item: a.asset_name,
          time: formatTimeAgo(new Date(a.created_at)),
          icon: Package,
          iconBg: 'bg-gradient-to-br from-emerald-400 to-emerald-500',
          timestamp: new Date(a.created_at)
        })
      })
    }

    if (staffRes.data) {
      staffRes.data.forEach(s => {
        activities.push({
          action: 'Staff added',
          item: s.name,
          time: formatTimeAgo(new Date(s.created_at)),
          icon: Users,
          iconBg: 'bg-gradient-to-br from-violet-400 to-violet-500',
          timestamp: new Date(s.created_at)
        })
      })
    }

    if (locationsRes.data) {
      locationsRes.data.forEach(l => {
        activities.push({
          action: 'Location added',
          item: l.name,
          time: formatTimeAgo(new Date(l.created_at)),
          icon: MapPin,
          iconBg: 'bg-gradient-to-br from-cyan-400 to-cyan-500',
          timestamp: new Date(l.created_at)
        })
      })
    }

    if (categoriesRes.data) {
      categoriesRes.data.forEach(c => {
        activities.push({
          action: 'Category added',
          item: c.name,
          time: formatTimeAgo(new Date(c.created_at)),
          icon: FolderTree,
          iconBg: 'bg-gradient-to-br from-amber-400 to-amber-500',
          timestamp: new Date(c.created_at)
        })
      })
    }

    if (licensesRes.data) {
      licensesRes.data.forEach(l => {
        activities.push({
          action: 'License added',
          item: l.name,
          time: formatTimeAgo(new Date(l.created_at)),
          icon: Key,
          iconBg: 'bg-gradient-to-br from-rose-400 to-rose-500',
          timestamp: new Date(l.created_at)
        })
      })
    }

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

    let active = 0
    let expiringSoon = 0
    let expired = 0
    let seatsUsed = 0
    let seatsTotal = 0

    licenseData.forEach(l => {
      seatsUsed += l.seats_used || 0
      seatsTotal += l.seats_total || 0

      if (!l.expiration_date) {
        active++
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
  <div class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-slate-50/50">
    <div class="p-6 lg:p-8 max-w-[1600px] mx-auto">
      <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-primary to-primary/80 flex items-center justify-center shadow-lg shadow-primary/25">
            <LayoutDashboard class="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-foreground tracking-tight">Dashboard</h1>
            <p class="text-sm text-muted-foreground">Welcome back! Here's your asset overview</p>
          </div>
        </div>
      </div>

      <!-- Loading state -->
      <div v-if="loading" class="grid grid-cols-2 lg:grid-cols-4 gap-5">
        <div v-for="i in 4" :key="i" class="h-32 bg-card rounded-2xl animate-pulse" />
      </div>

      <div v-else class="space-y-6">
        <!-- Stats Cards -->
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-5">
          <div
            v-for="stat in statCards"
            :key="stat.label"
            class="group relative bg-white rounded-2xl p-5 shadow-sm border border-slate-100 hover:shadow-xl hover:shadow-slate-200/50 hover:-translate-y-1 transition-all duration-300 cursor-pointer overflow-hidden"
            @click="navigateTo(stat.route)"
          >
            <!-- Decorative gradient blob -->
            <div :class="['absolute -top-10 -right-10 w-32 h-32 rounded-full opacity-10 blur-2xl transition-opacity group-hover:opacity-20', `bg-gradient-to-br ${stat.gradient}`]"></div>

            <div class="relative">
              <div class="flex items-start justify-between mb-4">
                <div :class="['w-11 h-11 rounded-xl bg-gradient-to-br flex items-center justify-center shadow-lg', stat.gradient]">
                  <component :is="stat.icon" class="w-5 h-5 text-white" />
                </div>
                <ArrowUpRight class="w-5 h-5 text-slate-300 group-hover:text-primary group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all" />
              </div>
              <p class="text-3xl font-bold text-foreground tracking-tight">{{ stat.value }}</p>
              <p class="text-sm text-muted-foreground mt-1">{{ stat.label }}</p>
            </div>
          </div>
        </div>

        <!-- Main Content Grid -->
        <div class="grid lg:grid-cols-3 gap-6">
          <!-- Asset Trends Chart -->
          <div class="lg:col-span-2 bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center">
                  <TrendingUp class="w-4 h-4 text-white" />
                </div>
                <div>
                  <h3 class="font-semibold text-foreground">Asset Trends</h3>
                  <p class="text-xs text-muted-foreground">Last 6 months overview</p>
                </div>
              </div>
              <!-- Legend -->
              <div class="hidden sm:flex items-center gap-4 text-xs">
                <div class="flex items-center gap-1.5">
                  <div class="w-2.5 h-2.5 rounded-full bg-emerald-500"></div>
                  <span class="text-muted-foreground">Active</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <div class="w-2.5 h-2.5 rounded-full bg-amber-500"></div>
                  <span class="text-muted-foreground">Maintenance</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <div class="w-2.5 h-2.5 rounded-full bg-slate-400"></div>
                  <span class="text-muted-foreground">Inactive</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <div class="w-2.5 h-2.5 rounded-full bg-red-500"></div>
                  <span class="text-muted-foreground">Disposed</span>
                </div>
              </div>
            </div>

            <!-- Chart -->
            <div v-if="monthlyData.length === 0" class="flex items-center justify-center h-56">
              <div class="text-center">
                <div class="w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center mx-auto mb-2">
                  <TrendingUp class="w-5 h-5 text-slate-400" />
                </div>
                <p class="text-sm text-muted-foreground">Loading chart data...</p>
              </div>
            </div>
            <div v-else class="h-56">
              <div class="flex items-end justify-between h-full gap-4 px-2">
                <div
                  v-for="data in monthlyData"
                  :key="`${data.month}-${data.year}`"
                  class="flex-1 flex flex-col h-full group/bar"
                >
                  <!-- Total badge -->
                  <div class="text-center mb-2 opacity-0 group-hover/bar:opacity-100 transition-opacity">
                    <span v-if="data.total > 0" class="inline-flex items-center justify-center px-2 py-0.5 text-[10px] font-bold bg-slate-900 text-white rounded-full">
                      {{ data.total }}
                    </span>
                  </div>
                  <!-- Bars -->
                  <div class="flex-1 flex items-end justify-center gap-1">
                    <div class="flex flex-col items-center justify-end h-full">
                      <span v-if="data.active > 0" class="text-[10px] font-semibold text-emerald-600 mb-1">{{ data.active }}</span>
                      <div
                        class="w-5 bg-gradient-to-t from-emerald-500 to-emerald-400 rounded-t-md transition-all duration-500 hover:from-emerald-600 hover:to-emerald-500"
                        :style="{ height: `${maxMonthly > 0 ? (data.active / maxMonthly) * 100 : 0}%`, minHeight: data.active > 0 ? '8px' : '0' }"
                      ></div>
                    </div>
                    <div class="flex flex-col items-center justify-end h-full">
                      <span v-if="data.maintenance > 0" class="text-[10px] font-semibold text-amber-600 mb-1">{{ data.maintenance }}</span>
                      <div
                        class="w-5 bg-gradient-to-t from-amber-500 to-amber-400 rounded-t-md transition-all duration-500 hover:from-amber-600 hover:to-amber-500"
                        :style="{ height: `${maxMonthly > 0 ? (data.maintenance / maxMonthly) * 100 : 0}%`, minHeight: data.maintenance > 0 ? '8px' : '0' }"
                      ></div>
                    </div>
                    <div class="flex flex-col items-center justify-end h-full">
                      <span v-if="data.inactive > 0" class="text-[10px] font-semibold text-slate-500 mb-1">{{ data.inactive }}</span>
                      <div
                        class="w-5 bg-gradient-to-t from-slate-400 to-slate-300 rounded-t-md transition-all duration-500 hover:from-slate-500 hover:to-slate-400"
                        :style="{ height: `${maxMonthly > 0 ? (data.inactive / maxMonthly) * 100 : 0}%`, minHeight: data.inactive > 0 ? '8px' : '0' }"
                      ></div>
                    </div>
                    <div class="flex flex-col items-center justify-end h-full">
                      <span v-if="data.disposed > 0" class="text-[10px] font-semibold text-red-600 mb-1">{{ data.disposed }}</span>
                      <div
                        class="w-5 bg-gradient-to-t from-red-500 to-red-400 rounded-t-md transition-all duration-500 hover:from-red-600 hover:to-red-500"
                        :style="{ height: `${maxMonthly > 0 ? (data.disposed / maxMonthly) * 100 : 0}%`, minHeight: data.disposed > 0 ? '8px' : '0' }"
                      ></div>
                    </div>
                  </div>
                  <!-- Month label -->
                  <div class="text-center pt-3 mt-2 border-t border-slate-100">
                    <span class="text-xs font-medium text-slate-600">{{ data.month }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Recent Activity -->
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
            <div class="flex items-center gap-3 mb-5">
              <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-violet-500 to-violet-600 flex items-center justify-center">
                <Activity class="w-4 h-4 text-white" />
              </div>
              <div>
                <h3 class="font-semibold text-foreground">Recent Activity</h3>
                <p class="text-xs text-muted-foreground">Latest updates</p>
              </div>
            </div>

            <div v-if="recentActivities.length === 0" class="text-center py-8">
              <div class="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center mx-auto mb-3">
                <Clock class="w-6 h-6 text-slate-400" />
              </div>
              <p class="text-sm text-muted-foreground">No recent activity</p>
            </div>
            <div v-else class="max-h-[280px] overflow-y-auto space-y-4 pr-1 scrollbar-thin">
              <div v-for="group in activitiesByDate" :key="group.date">
                <div class="sticky top-0 bg-white py-1.5 mb-2 z-10">
                  <span class="text-[11px] font-semibold text-primary uppercase tracking-wider">{{ group.label }}</span>
                </div>
                <div class="space-y-2">
                  <div
                    v-for="(activity, index) in group.activities"
                    :key="index"
                    class="flex items-center gap-3 p-2 rounded-xl hover:bg-slate-50 transition-colors"
                  >
                    <div :class="['w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 shadow-sm', activity.iconBg]">
                      <component :is="activity.icon" class="w-3.5 h-3.5 text-white" />
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-foreground truncate">{{ activity.item }}</p>
                    </div>
                    <span class="text-[11px] text-muted-foreground font-medium">{{ activity.time }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Status Cards Row -->
        <div class="grid lg:grid-cols-2 gap-6">
          <!-- Asset Status -->
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-emerald-500 to-emerald-600 flex items-center justify-center">
                  <Package class="w-4 h-4 text-white" />
                </div>
                <div>
                  <h3 class="font-semibold text-foreground">Asset Status</h3>
                  <p class="text-xs text-muted-foreground">Current distribution</p>
                </div>
              </div>
              <div class="text-right">
                <span class="text-2xl font-bold text-foreground">{{ stats.totalAssets }}</span>
                <p class="text-[11px] text-muted-foreground">Total</p>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <!-- Active -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-emerald-50 to-emerald-100/50 border border-emerald-100 hover:shadow-md hover:shadow-emerald-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <CheckCircle2 class="w-4 h-4 text-emerald-600" />
                    <span class="text-sm font-medium text-emerald-700">Active</span>
                  </div>
                  <span class="text-xl font-bold text-emerald-600">{{ stats.activeAssets }}</span>
                </div>
                <div class="h-2 bg-emerald-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-emerald-500 to-emerald-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalAssets ? (stats.activeAssets / stats.totalAssets) * 100 : 0}%` }"></div>
                </div>
              </div>

              <!-- Maintenance -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-amber-50 to-amber-100/50 border border-amber-100 hover:shadow-md hover:shadow-amber-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <AlertTriangle class="w-4 h-4 text-amber-600" />
                    <span class="text-sm font-medium text-amber-700">Maintenance</span>
                  </div>
                  <span class="text-xl font-bold text-amber-600">{{ stats.maintenanceAssets }}</span>
                </div>
                <div class="h-2 bg-amber-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-amber-500 to-amber-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalAssets ? (stats.maintenanceAssets / stats.totalAssets) * 100 : 0}%` }"></div>
                </div>
              </div>

              <!-- Inactive -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-slate-50 to-slate-100/50 border border-slate-200 hover:shadow-md hover:shadow-slate-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <XCircle class="w-4 h-4 text-slate-500" />
                    <span class="text-sm font-medium text-slate-600">Inactive</span>
                  </div>
                  <span class="text-xl font-bold text-slate-600">{{ stats.inactiveAssets }}</span>
                </div>
                <div class="h-2 bg-slate-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-slate-500 to-slate-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalAssets ? (stats.inactiveAssets / stats.totalAssets) * 100 : 0}%` }"></div>
                </div>
              </div>

              <!-- Disposed -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-red-50 to-red-100/50 border border-red-100 hover:shadow-md hover:shadow-red-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <Trash2 class="w-4 h-4 text-red-600" />
                    <span class="text-sm font-medium text-red-700">Disposed</span>
                  </div>
                  <span class="text-xl font-bold text-red-600">{{ stats.disposedAssets }}</span>
                </div>
                <div class="h-2 bg-red-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-red-500 to-red-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalAssets ? (stats.disposedAssets / stats.totalAssets) * 100 : 0}%` }"></div>
                </div>
              </div>
            </div>
          </div>

          <!-- License Status -->
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-rose-500 to-rose-600 flex items-center justify-center">
                  <Key class="w-4 h-4 text-white" />
                </div>
                <div>
                  <h3 class="font-semibold text-foreground">License Status</h3>
                  <p class="text-xs text-muted-foreground">Software licenses</p>
                </div>
              </div>
              <div class="text-right">
                <span class="text-2xl font-bold text-foreground">{{ stats.totalLicenses }}</span>
                <p class="text-[11px] text-muted-foreground">Total</p>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <!-- Active -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-emerald-50 to-emerald-100/50 border border-emerald-100 hover:shadow-md hover:shadow-emerald-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <CheckCircle2 class="w-4 h-4 text-emerald-600" />
                    <span class="text-sm font-medium text-emerald-700">Active</span>
                  </div>
                  <span class="text-xl font-bold text-emerald-600">{{ licenseStats.active }}</span>
                </div>
                <div class="h-2 bg-emerald-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-emerald-500 to-emerald-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalLicenses ? (licenseStats.active / stats.totalLicenses) * 100 : 0}%` }"></div>
                </div>
              </div>

              <!-- Expiring Soon -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-amber-50 to-amber-100/50 border border-amber-100 hover:shadow-md hover:shadow-amber-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <AlertTriangle class="w-4 h-4 text-amber-600" />
                    <span class="text-sm font-medium text-amber-700">Expiring</span>
                  </div>
                  <span class="text-xl font-bold text-amber-600">{{ licenseStats.expiringSoon }}</span>
                </div>
                <div class="h-2 bg-amber-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-amber-500 to-amber-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalLicenses ? (licenseStats.expiringSoon / stats.totalLicenses) * 100 : 0}%` }"></div>
                </div>
              </div>

              <!-- Expired -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-red-50 to-red-100/50 border border-red-100 hover:shadow-md hover:shadow-red-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <XCircle class="w-4 h-4 text-red-600" />
                    <span class="text-sm font-medium text-red-700">Expired</span>
                  </div>
                  <span class="text-xl font-bold text-red-600">{{ licenseStats.expired }}</span>
                </div>
                <div class="h-2 bg-red-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-red-500 to-red-400 rounded-full transition-all duration-700" :style="{ width: `${stats.totalLicenses ? (licenseStats.expired / stats.totalLicenses) * 100 : 0}%` }"></div>
                </div>
              </div>

              <!-- Seats Used -->
              <div class="group p-4 rounded-xl bg-gradient-to-br from-sky-50 to-sky-100/50 border border-sky-100 hover:shadow-md hover:shadow-sky-100 transition-all">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <Users class="w-4 h-4 text-sky-600" />
                    <span class="text-sm font-medium text-sky-700">Seats</span>
                  </div>
                  <span class="text-xl font-bold text-sky-600">{{ licenseStats.seatsUsed }}<span class="text-sm font-normal text-sky-400">/{{ licenseStats.seatsTotal }}</span></span>
                </div>
                <div class="h-2 bg-sky-200/50 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-sky-500 to-sky-400 rounded-full transition-all duration-700" :style="{ width: `${licenseStats.seatsTotal ? (licenseStats.seatsUsed / licenseStats.seatsTotal) * 100 : 0}%` }"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.scrollbar-thin::-webkit-scrollbar {
  width: 4px;
}
.scrollbar-thin::-webkit-scrollbar-track {
  background: transparent;
}
.scrollbar-thin::-webkit-scrollbar-thumb {
  background: #e2e8f0;
  border-radius: 4px;
}
.scrollbar-thin::-webkit-scrollbar-thumb:hover {
  background: #cbd5e1;
}
</style>
