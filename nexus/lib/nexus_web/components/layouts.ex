defmodule NexusWeb.Layouts do
  use NexusWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders flash messages
  """
  def flash_group(assigns) do
    assigns = assign_new(assigns, :flash, fn -> %{} end)

    ~H"""
    <div class="space-y-2">
      <%= if message = @flash["info"] do %>
        <div class="rounded-md bg-blue-50 p-4">
          <p class="text-sm text-blue-700"><%= message %></p>
        </div>
      <% end %>
      <%= if message = @flash["error"] do %>
        <div class="rounded-md bg-red-50 p-4">
          <p class="text-sm text-red-700"><%= message %></p>
        </div>
      <% end %>
    </div>
    """
  end
end
