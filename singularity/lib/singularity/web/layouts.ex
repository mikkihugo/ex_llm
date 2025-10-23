defmodule Singularity.Web.Layouts do
  @moduledoc """
  Layout components for Phoenix LiveView and controller actions.

  Provides:
  - app/1 - Admin layout with header and sidebar navigation
  - Header and sidebar components
  """
  use Phoenix.Component

  @doc """
  Renders the admin layout with header and sidebar for LiveView pages.
  """
  def app(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Singularity</title>
      </head>
      <body class="bg-gray-50">
        <div class="flex h-screen bg-gray-100">
          <!-- Sidebar -->
          <.sidebar />

          <!-- Main Content -->
          <div class="flex-1 flex flex-col overflow-hidden">
            <!-- Header -->
            <.header />

            <!-- Page Content -->
            <main class="flex-1 overflow-auto bg-gray-50">
              <div class="max-w-7xl mx-auto">
                <%= render_slot(@inner_block) %>
              </div>
            </main>
          </div>
        </div>
      </body>
    </html>
    """
  end

  @doc """
  Renders the sidebar navigation.
  """
  def sidebar(assigns) do
    ~H"""
      <div class="hidden md:flex md:flex-col md:fixed md:inset-y-0 md:w-64 bg-gray-900">
        <!-- Logo -->
        <div class="flex items-center justify-center h-16 px-4 bg-gray-800 border-b border-gray-700">
          <div class="flex items-center space-x-2">
            <div class="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <span class="text-lg font-bold text-white">Singularity</span>
          </div>
        </div>

        <!-- Navigation -->
        <nav class="flex-1 px-2 py-6 space-y-2 overflow-y-auto">
          <!-- Home -->
          <a href="/" class="group flex items-center px-4 py-2 text-sm font-medium rounded-lg text-gray-300 hover:bg-gray-800 hover:text-white transition-colors">
            <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-3m0 0l7-4 7 4M5 9v10a1 1 0 001 1h12a1 1 0 001-1V9m-9 11l4-4m0 0l4 4m-4-4V3" />
            </svg>
            Home
          </a>

          <!-- Approvals -->
          <a href="/approvals" class="group flex items-center px-4 py-2 text-sm font-medium rounded-lg text-gray-300 hover:bg-gray-800 hover:text-white transition-colors">
            <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Approvals
          </a>

          <!-- Documentation -->
          <a href="/documentation" class="group flex items-center px-4 py-2 text-sm font-medium rounded-lg text-gray-300 hover:bg-gray-800 hover:text-white transition-colors">
            <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Documentation
          </a>

          <!-- Dashboard -->
          <a href="/dashboard" class="group flex items-center px-4 py-2 text-sm font-medium rounded-lg text-gray-300 hover:bg-gray-800 hover:text-white transition-colors">
            <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            Dashboard
          </a>
        </nav>

        <!-- Footer -->
        <div class="p-4 border-t border-gray-700">
          <p class="text-xs text-gray-400">v1.0</p>
          <p class="text-xs text-gray-500 mt-1">Internal Tooling</p>
        </div>
      </div>
    """
  end

  @doc """
  Renders the header with branding and system info.
  """
  def header(assigns) do
    ~H"""
      <header class="md:ml-64 bg-white border-b border-gray-200 shadow-sm">
        <div class="flex items-center justify-between h-16 px-4 sm:px-6 lg:px-8">
          <!-- Mobile menu button -->
          <button class="md:hidden inline-flex items-center justify-center p-2 rounded-md text-gray-500 hover:text-gray-900 hover:bg-gray-100">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          <!-- Title -->
          <div class="flex-1 md:block">
            <h1 class="text-2xl font-semibold text-gray-900">Singularity</h1>
          </div>

          <!-- Right side: System status -->
          <div class="flex items-center space-x-4">
            <div class="flex items-center space-x-2 px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
              <div class="w-2 h-2 bg-green-500 rounded-full"></div>
              <span class="text-sm text-gray-600 font-medium">System Online</span>
            </div>
          </div>
        </div>
      </header>
    """
  end
end
