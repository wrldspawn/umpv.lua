# umpv.lua

An opinionated rewrite of [umpv](https://github.com/mpv-player/mpv/blob/master/TOOLS/umpv) and [umpv-go](https://github.com/zhongfly/umpv-go) in Lua.

> This script emulates "unique application" functionality. When starting playback with this script, it will try to reuse
> an already running instance of mpv (but only if that was started with umpv). Other mpv instances (not started by umpv)
> are ignored, and the script doesn't know about them.

The point of this rewrite is to remove any forced options (to return control to the user without modifying the script)
while also allowing extensibility (removing the "Custom options can't be used" limitation from umpv).

For example, umpv forces `profile=builtin-pseudo-gui`, umpv-go forces _either_ `force-window=yes` or
`force-minimized=yes` depending on the value of the `--foreground` flag, which has now been removed not only because of
this functionality but because it can't be cleanly implemented for non-Windows operating systems.

All options should be controlled by the user, whether that be through their `mpv.conf` or the flags they specify in the
command line.

## Building

You will need [luvi](https://github.com/luvit/luvi) compiled with luajit

```sh
luvi . -o umpv --strip # umpv.exe on Windows
```

## Options

All flags designated after `--` will be passed to mpv.

### `--ipc-server`

The IPC socket path to connect to. Default path is `\\.\pipe\umpv` on Windows and
`$($UMPV_SOCKET_DIR || $XDG_RUNTIME_DIR || $HOME || $TMPDIR)/.umpv` on everything else.

### `--loadfile-flag`

How files should be added to mpv's playlist. Supported values are:

- `replace`: Replace the playlist
- `append`: Append to the playlist
- `append-play`: If nothing is playing, play the file, otherwise append to the playlist **(default)**
- `insert-next`: Add to the playlist after current item
- `insert-next-play`: If nothing is playing, play the file, otherwise add to the playlist after current item

### `--config`

Load this specific file as `umpv.conf` instead of the one found in mpv's config directory or next to the executable.

### `--keep-process`

Keeps the `umpv` process lingering. This can be used to trick [streamlink](https://github.com/streamlink/streamlink)
without having to use `--player-external-http`.

## Examples

### Generic usage

```sh
umpv file_or_url
```

```sh
umpv -- --force-media-title="some title" file_or_url
```

### [mpv-install](https://github.com/rossy/mpv-install)

> [!TIP]
> If you have Visual Studio Build Tools installed, run `editbin /subsystem:windows umpv.exe` to prevent umpv from
> creating a console window.

```bat
set mpv_args=--loadfile-flag=replace --ipc-server=\\.\pipe\umpv-file -- --idle=yes --resume-playback=no --save-position-on-quit=no
set mpv_path=%userprofile%\.local\bin\umpv.exe
```

### [streamlink](https://github.com/streamlink/streamlink)

<!-- prettier-ignore-start -->
> [!WARNING]
> **streamlink defaults to stdin which will not work!** Use either `--player-fifo` or `--player-http`.
<!-- prettier-ignore-end -->

> [!NOTE]
> streamlink has a strict regex check for `^mpv$`, `--title` and `{playertitleargs}` will have no effect and only show
> the pipe name or the URL as the title depending on which player type is used.

```sh
streamlink --player-fifo -p umpv -a "--keep-process=yes --" url best
```
