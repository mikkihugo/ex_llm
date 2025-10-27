defmodule ObserverWeb.AuthHTML do
  @moduledoc """
  This module contains pages rendered by AuthController.

  See the `auth_html` directory for all templates.
  """
  use ObserverWeb, :html

  embed_templates "auth_html/*"
end
