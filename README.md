# umpv.lua

A rewrite of [umpv](https://github.com/mpv-player/mpv/blob/master/TOOLS/umpv) and [umpv-go](https://github.com/zhongfly/umpv-go) in Lua.

## Differences

### umpv

- Does not force `profile`

### umpv.go

- Actually FOSS
- Not Windows only
  - This is untested at the moment ~~because I'm lazy~~, but should work as it just uses `uv`
- `foreground` removed as theres no clean way to reimplement it to where it can support both X11 and Wayland
  - It is also really annoying that disabling foreground forces `window-minimized=yes`
- Reads `umpv.conf` from mpv config directory, not just next to executable
- Does not force `force-window` and `idle`

### Both

- All flags designated after `--` will be passed to mpv
  - e.g. `umpv --loadfile-flag=replace -- --force-media-title="some title" somefile.mp4` will load `somefile.mp4` with
    the title "some title"

## New Flags

### `--keep-process`

Keeps the `umpv` process lingering. This can be used to trick [streamlink](https://github.com/streamlink/streamlink)
without having to use `--player-external-http`.

> [!NOTE]
> Specifically for streamlink you will have to specify either `--player-http` or `--player-fifo`
> e.g. `streamlink --player-fifo -p umpv -a "--keep-process=yes --" url best`

## Building

You will need [luvi](https://github.com/luvit/luvi) compiled with luajit

```sh
luvi . -o umpv --strip
```
