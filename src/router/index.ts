import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '@/lib/supabase'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'landing',
      component: () => import('@/views/Landing.vue'),
      meta: { guest: true }
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/Login.vue'),
      meta: { guest: true }
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: () => import('@/views/Dashboard.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/assets',
      name: 'assets',
      component: () => import('@/views/Assets.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/categories',
      name: 'categories',
      component: () => import('@/views/Categories.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/staff',
      name: 'staff',
      component: () => import('@/views/Staff.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/locations',
      name: 'locations',
      component: () => import('@/views/Locations.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/licenses',
      name: 'licenses',
      component: () => import('@/views/Licenses.vue'),
      meta: { requiresAuth: true }
    }
  ]
})

// Auth guard
router.beforeEach(async (to, _from, next) => {
  const { data: { session } } = await supabase.auth.getSession()

  if (to.meta.requiresAuth && !session) {
    next({ name: 'login' })
  } else if (to.meta.guest && session) {
    next({ name: 'dashboard' })
  } else {
    next()
  }
})

export default router
