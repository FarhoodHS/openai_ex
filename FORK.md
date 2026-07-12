# Fork notes

Customized fork of [`cyberchitta/openai_ex`](https://github.com/cyberchitta/openai_ex)
with streaming support for the Audio TTS endpoint.

## Layout

| Branch | Purpose |
|--------|---------|
| `main`   | Clean mirror of upstream — never commit custom code here |
| `custom` | Our changes on top of upstream (this is what projects depend on) |

Remotes: `origin` = `FarhoodHS/openai_ex.git`, `upstream` = `cyberchitta/openai_ex.git`.

## What's customized (`custom` only)

- `lib/openai_ex/audio/speech.ex` — adds `stream: true` with `stream_format: "sse"`
  (SSE) or default (binary), plus `:instructions` / `:stream_format` fields.
- `lib/openai_ex/http_binary_stream.ex` — new module for raw binary streaming.

## Pull upstream fixes

```sh
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout custom && git rebase main && git push --force-with-lease origin custom
```

Because `custom` descends from real upstream history, the rebase only replays the
two files above.

## Consuming it (e.g. TheFirstClass)

```elixir
{:openai_ex, git: "https://github.com/FarhoodHS/openai_ex.git", branch: "custom"}
```

Run `mix deps.update openai_ex` to advance the lock after pushing new `custom` commits.
