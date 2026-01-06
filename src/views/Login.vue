<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { Package, ArrowRight, Eye, EyeOff } from 'lucide-vue-next'

const router = useRouter()
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const showPassword = ref(false)

async function handleLogin() {
  loading.value = true
  error.value = ''

  try {
    const { error: authError } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value
    })

    if (authError) throw authError
    router.push({ name: 'dashboard' })
  } catch (e: any) {
    error.value = e.message || 'Login failed'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex bg-background">
    <!-- Left side - Branding -->
    <div class="hidden lg:flex lg:w-1/2 bg-sidebar relative overflow-hidden">
      <!-- Subtle pattern -->
      <div class="absolute inset-0 opacity-[0.03]" style="background-image: url('data:image/svg+xml,%3Csvg width=&quot;60&quot; height=&quot;60&quot; viewBox=&quot;0 0 60 60&quot; xmlns=&quot;http://www.w3.org/2000/svg&quot;%3E%3Cg fill=&quot;none&quot; fill-rule=&quot;evenodd&quot;%3E%3Cg fill=&quot;%23ffffff&quot; fill-opacity=&quot;1&quot;%3E%3Cpath d=&quot;M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z&quot;/%3E%3C/g%3E%3C/g%3E%3C/svg%3E');" />

      <!-- Gradient overlay -->
      <div class="absolute inset-0 bg-gradient-to-br from-sidebar-accent/20 via-transparent to-transparent" />

      <!-- Content -->
      <div class="relative z-10 flex flex-col justify-between p-12 w-full">
        <!-- Logo -->
        <div class="flex items-center gap-3">
          <div class="w-12 h-12 rounded-xl bg-sidebar-accent flex items-center justify-center shadow-lg shadow-sidebar-accent/30">
            <Package class="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 class="text-xl font-semibold text-sidebar-foreground">Asset Manager</h1>
            <p class="text-sm text-sidebar-foreground/50">Inventory System</p>
          </div>
        </div>

        <!-- Main text -->
        <div class="max-w-md">
          <h2 class="text-4xl font-semibold text-sidebar-foreground leading-tight tracking-tight">
            Manage your assets with clarity and control
          </h2>
          <p class="mt-4 text-lg text-sidebar-foreground/60 leading-relaxed">
            Track equipment, licenses, and team assignments all in one centralized platform.
          </p>
        </div>

        <!-- Footer -->
        <p class="text-sm text-sidebar-foreground/30">
          Powered by Supabase
        </p>
      </div>
    </div>

    <!-- Right side - Login form -->
    <div class="flex-1 flex items-center justify-center p-6 lg:p-12">
      <div class="w-full max-w-sm animate-slide-up">
        <!-- Mobile logo -->
        <div class="lg:hidden flex items-center gap-3 mb-10">
          <div class="w-11 h-11 rounded-xl bg-primary flex items-center justify-center">
            <Package class="w-5 h-5 text-primary-foreground" />
          </div>
          <div>
            <h1 class="text-lg font-semibold text-foreground">Asset Manager</h1>
            <p class="text-xs text-muted-foreground">Inventory System</p>
          </div>
        </div>

        <!-- Header -->
        <div class="mb-8">
          <h2 class="text-2xl font-semibold text-foreground tracking-tight">Welcome back</h2>
          <p class="mt-2 text-muted-foreground">Sign in to continue to your dashboard</p>
        </div>

        <!-- Form -->
        <form @submit.prevent="handleLogin" class="space-y-5">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Email address</label>
            <input
              v-model="email"
              type="email"
              required
              autocomplete="email"
              class="w-full h-12 px-4 bg-card border border-border rounded-xl text-foreground placeholder:text-muted-foreground/60 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
              placeholder="you@company.com"
            />
          </div>

          <div class="space-y-2">
            <label class="block text-sm font-medium text-foreground">Password</label>
            <div class="relative">
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                required
                autocomplete="current-password"
                class="w-full h-12 px-4 pr-12 bg-card border border-border rounded-xl text-foreground placeholder:text-muted-foreground/60 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                placeholder="Enter your password"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                class="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
              >
                <Eye v-if="!showPassword" class="w-5 h-5" />
                <EyeOff v-else class="w-5 h-5" />
              </button>
            </div>
          </div>

          <!-- Error message -->
          <div v-if="error" class="p-3 bg-destructive/10 border border-destructive/20 rounded-xl">
            <p class="text-sm text-destructive">{{ error }}</p>
          </div>

          <!-- Submit button -->
          <button
            type="submit"
            :disabled="loading"
            class="group w-full h-12 bg-primary text-primary-foreground rounded-xl font-medium flex items-center justify-center gap-2 hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-all active:scale-[0.98]"
          >
            <span>{{ loading ? 'Signing in...' : 'Sign in' }}</span>
            <ArrowRight v-if="!loading" class="w-4 h-4 group-hover:translate-x-0.5 transition-transform" />
          </button>
        </form>
      </div>
    </div>
  </div>
</template>
