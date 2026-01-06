<script setup lang="ts">
import { Package, ArrowRight, BarChart3, Shield, Users } from 'lucide-vue-next'
</script>

<template>
  <div class="min-h-screen bg-background">
    <!-- Header -->
    <header class="border-b bg-card/80 backdrop-blur-sm sticky top-0 z-50">
      <div class="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-xl bg-primary flex items-center justify-center">
            <Package class="w-5 h-5 text-primary-foreground" />
          </div>
          <span class="font-semibold text-foreground">Asset Manager</span>
        </div>
        <RouterLink
          to="/login"
          class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg font-medium hover:opacity-90 transition-all text-sm"
        >
          Sign In
          <ArrowRight class="w-4 h-4" />
        </RouterLink>
      </div>
    </header>

    <!-- Hero -->
    <section class="py-20 px-6">
      <div class="max-w-4xl mx-auto text-center">
        <h1 class="text-4xl md:text-5xl font-bold text-foreground tracking-tight leading-tight">
          Manage your assets<br />
          <span class="text-primary">with clarity and control</span>
        </h1>
        <p class="mt-6 text-lg text-muted-foreground max-w-2xl mx-auto">
          Track equipment, software licenses, and team assignments all in one centralized platform.
          Simple, efficient, and built for modern teams.
        </p>
        <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <RouterLink
            to="/login"
            class="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-xl font-medium hover:opacity-90 transition-all shadow-lg shadow-primary/20"
          >
            Get Started
            <ArrowRight class="w-4 h-4" />
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- Features -->
    <section class="py-16 px-6 bg-muted/30">
      <div class="max-w-5xl mx-auto">
        <h2 class="text-2xl font-semibold text-center text-foreground mb-12">Everything you need</h2>
        <div class="grid md:grid-cols-3 gap-6">
          <div class="bg-card border rounded-2xl p-6">
            <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-4">
              <Package class="w-6 h-6 text-primary" />
            </div>
            <h3 class="font-semibold text-foreground mb-2">Asset Tracking</h3>
            <p class="text-sm text-muted-foreground">
              Keep track of all your equipment with detailed records and status updates.
            </p>
          </div>
          <div class="bg-card border rounded-2xl p-6">
            <div class="w-12 h-12 rounded-xl bg-emerald-500/10 flex items-center justify-center mb-4">
              <Users class="w-6 h-6 text-emerald-600" />
            </div>
            <h3 class="font-semibold text-foreground mb-2">Staff Management</h3>
            <p class="text-sm text-muted-foreground">
              Assign assets to team members and track who has what equipment.
            </p>
          </div>
          <div class="bg-card border rounded-2xl p-6">
            <div class="w-12 h-12 rounded-xl bg-amber-500/10 flex items-center justify-center mb-4">
              <Shield class="w-6 h-6 text-amber-600" />
            </div>
            <h3 class="font-semibold text-foreground mb-2">License Tracking</h3>
            <p class="text-sm text-muted-foreground">
              Never miss a renewal with expiration alerts and seat management.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- Footer -->
    <footer class="py-8 px-6 border-t">
      <div class="max-w-6xl mx-auto text-center text-sm text-muted-foreground">
        <p>Powered by Vue + Supabase</p>
      </div>
    </footer>
  </div>
</template>
