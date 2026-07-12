defmodule OpenaiEx.HttpBinaryStream do
  @moduledoc false
  # Streams a non-SSE response body (e.g. raw audio/mpeg from /audio/speech with
  # stream_format: "audio") as a Stream of binary chunks.
  alias OpenaiEx.{HttpFinch, Error}
  require Logger

  def post(openai = %OpenaiEx{}, url, json: json) do
    me = self()
    ref = make_ref()
    request = HttpFinch.build_post(openai, url, json: json)
    task = Task.async(fn -> finch_stream(openai, request, me, ref) end)
    result = build_binary_stream(openai, task, request, ref)
    unless match?({:ok, %{task_pid: _}}, result), do: Task.shutdown(task)
    result
  end

  def cancel_request(task_pid) when is_pid(task_pid), do: send(task_pid, :cancel_request)

  defp build_binary_stream(openai, task, request, ref) do
    with {:ok, status} <- recv(ref, :status, openai.receive_timeout),
         {:ok, headers} <- recv(ref, :headers, openai.receive_timeout) do
      if status in 200..299 do
        body_stream =
          Stream.resource(
            fn -> :ok end,
            receiver(ref, openai.stream_timeout),
            end_stream(task)
          )

        {:ok, %{status: status, headers: headers, body_stream: body_stream, task_pid: task.pid}}
      else
        with {:ok, body} <- drain_error(ref, "", openai.receive_timeout) do
          decoded =
            with {:ok, json} <- Jason.decode(body), do: json, else: (_ -> body)

          response = %{status: status, headers: headers, body: decoded}
          {:error, Error.status_error(status, response, decoded)}
        else
          err -> handle_receive_error(err, request)
        end
      end
    else
      err -> handle_receive_error(err, request)
    end
  end

  defp handle_receive_error(:error, request), do: {:error, Error.api_timeout_error(request)}

  defp handle_receive_error({:error, {:stream_error, exception}}, request),
    do: HttpFinch.to_error(exception, request)

  defp receiver(ref, timeout) do
    fn acc ->
      receive do
        {:chunk, {:data, bin}, ^ref} ->
          {[bin], acc}

        {:done, ^ref} ->
          {:halt, acc}

        {:stream_error, exception, ^ref} ->
          Logger.warning("Finch stream error: #{inspect(exception)}")
          {:halt, {:exception, {:stream_error, exception}}}

        {:canceled, ^ref} ->
          Logger.info("Request canceled by user")
          {:halt, {:exception, :canceled}}
      after
        timeout ->
          Logger.warning("Binary stream timeout after #{timeout}ms")
          {:halt, {:exception, :timeout}}
      end
    end
  end

  defp end_stream(task) do
    fn acc ->
      try do
        case acc do
          {:exception, :timeout} -> raise(Error.sse_timeout_error())
          {:exception, :canceled} -> raise(Error.sse_user_cancellation())
          {:exception, {:stream_error, exception}} -> raise(HttpFinch.to_error!(exception, nil))
          _ -> :ok
        end
      after
        Task.shutdown(task)
      end
    end
  end

  defp finch_stream(openai = %OpenaiEx{}, request, me, ref) do
    try do
      case HttpFinch.stream(request, openai, create_chunk_sender(me, ref)) do
        {:ok, _acc} -> send(me, {:done, ref})
        {:error, exception, _acc} -> send(me, {:stream_error, exception, ref})
      end
    catch
      :throw, :cancel_request -> {:exception, :cancel_request}
    end
  end

  defp create_chunk_sender(me, ref) do
    fn chunk, _acc ->
      receive do
        :cancel_request ->
          send(me, {:canceled, ref})
          throw(:cancel_request)
      after
        0 -> send(me, {:chunk, chunk, ref})
      end
    end
  end

  defp recv(ref, type, timeout) do
    receive do
      {:chunk, {^type, value}, ^ref} -> {:ok, value}
      {:stream_error, exception, ^ref} -> {:error, {:stream_error, exception}}
    after
      timeout -> :error
    end
  end

  defp drain_error(ref, acc, timeout) do
    receive do
      {:chunk, {:data, c}, ^ref} -> drain_error(ref, acc <> c, timeout)
      {:done, ^ref} -> {:ok, acc}
      {:stream_error, exception, ^ref} -> {:error, {:stream_error, exception}}
    after
      timeout -> :error
    end
  end
end
