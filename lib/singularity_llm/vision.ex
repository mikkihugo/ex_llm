defmodule SingularityLLM.Vision do
  @moduledoc """
  Vision-related functionality for SingularityLLM.

  This module provides functions for working with vision capabilities,
  including checking model support, loading images, and creating vision messages.
  """

  @doc """
  Check if a provider/model combination supports vision.

  ## Examples

      SingularityLLM.Vision.supports_vision?(:openai, "gpt-4-vision-preview")
      # => true
  """
  def supports_vision?(provider, model) do
    SingularityLLM.model_supports?(provider, model, :vision)
  end

  @doc """
  Load an image from a file path or URL.

  ## Examples

      {:ok, image_data} = SingularityLLM.Vision.load_image("/path/to/image.jpg")
  """
  def load_image(path, opts \\ []) do
    SingularityLLM.Core.Vision.load_image(path, opts)
  end

  @doc """
  Create a vision message with text and images.

  ## Examples

      {:ok, message} = SingularityLLM.Vision.vision_message("What's in this image?", ["https://example.com/img.jpg"])
  """
  def vision_message(text, images, opts \\ []) do
    SingularityLLM.Core.Vision.create_message(text, images, opts)
  end
end
