defmodule OpenaiEx.OpenRouter.ImagesTest do
  use ExUnit.Case, async: true
  alias OpenaiEx.OpenRouter.Images

  test "new/1 keeps only whitelisted OpenRouter image fields" do
    req =
      Images.new(%{
        model: "google/gemini-2.5-flash-image",
        prompt: "a red bicycle",
        resolution: "2K",
        aspect_ratio: "16:9",
        provider: %{"options" => %{}},
        not_a_field: "drop me"
      })

    assert req == %{
             model: "google/gemini-2.5-flash-image",
             prompt: "a red bicycle",
             resolution: "2K",
             aspect_ratio: "16:9",
             provider: %{"options" => %{}}
           }
  end

  test "new/1 accepts a keyword list" do
    assert Images.new(model: "m", prompt: "p") == %{model: "m", prompt: "p"}
  end
end
