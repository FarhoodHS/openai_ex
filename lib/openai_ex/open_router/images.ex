defmodule OpenaiEx.OpenRouter.Images do
  @moduledoc """
  OpenRouter image generation.

  Calls `POST {base_url}/images` where `base_url` ends in `/api/v1`. This is a
  dedicated OpenRouter endpoint and is **not** OpenAI's `/images/generations`; it is a
  sibling of `OpenaiEx.Images`, which is left untouched.

  The OpenRouter API reference: https://openrouter.ai/docs/api/api-reference/images/create-images
  """
  alias OpenaiEx.{Http, HttpSse}

  @ep_url "/images"

  @api_fields [
    :model,
    :prompt,
    :n,
    :resolution,
    :aspect_ratio,
    :quality,
    :output_format,
    :seed,
    :provider,
    :response_format
  ]

  @doc """
  Builds a request map, keeping only OpenRouter image fields.

  Accepts a keyword list or a map.

      iex> OpenaiEx.OpenRouter.Images.new(model: "m", prompt: "p")
      %{model: "m", prompt: "p"}
  """
  def new(args = [_ | _]), do: args |> Enum.into(%{}) |> new()
  def new(args = %{}), do: Map.take(args, @api_fields)

  @doc """
  Streaming image generation (SSE).

  Returns `{:ok, %{status, headers, body_stream, task_pid}}` or
  `{:error, %OpenaiEx.Error{}}`.
  """
  def create!(openai = %OpenaiEx{}, body = %{}, stream: true) do
    openai |> create(body, stream: true) |> Http.bang_it!()
  end

  def create(openai = %OpenaiEx{}, body = %{}, stream: true) do
    ep = Map.get(openai, :_ep_path_mapping).(@ep_url)
    openai |> HttpSse.post(ep, json: body |> Map.take(@api_fields) |> Map.put(:stream, true))
  end

  @doc """
  Buffered image generation.

  Returns `{:ok, decoded_map}` or `{:error, %OpenaiEx.Error{}}`.
  """
  def create!(openai = %OpenaiEx{}, body = %{}) do
    openai |> create(body) |> Http.bang_it!()
  end

  def create(openai = %OpenaiEx{}, body = %{}) do
    ep = Map.get(openai, :_ep_path_mapping).(@ep_url)
    openai |> Http.post(ep, json: Map.take(body, @api_fields))
  end
end
