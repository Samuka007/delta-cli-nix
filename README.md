# delta-cli-nix

A CLI-only Nix package for [Delta](https://delta.dev), for use on NixOS and other
Nix systems. It installs the `delta` command that coding-agent plugins drive
(`delta --json thread append …`) without packaging the desktop application's
icons or `.desktop` entries.

Deliberately not depending on [`zed-industries/delta-nix`](https://github.com/zed-industries/delta-nix):
that flake is the full desktop app, pulling Vulkan, Wayland, X11, and fontconfig
into a ~425 MiB closure. This one pulls only what the CLI links against.

## Usage

```nix
inputs.delta-cli.url = "github:Samuka007/delta-cli-nix";
inputs.delta-cli.inputs.nixpkgs.follows = "nixpkgs";
```

Then add `inputs.delta-cli.packages.${pkgs.stdenv.hostPlatform.system}.delta-cli`
to `environment.systemPackages` (NixOS) or `home.packages` (Home Manager).

Requires `config.allowUnfree = true` — Delta is proprietary.

```sh
nix run github:Samuka007/delta-cli-nix      # try it
nix build github:Samuka007/delta-cli-nix    # build only
```

## What you get

- `bin/delta` — the CLI, on PATH. This is what agent plugins need.
- `bin/delta-app` — the windowless backend, **required**, see below.

`delta thread …` and `delta worktree …` talk to the server directly and work on
their own. `org`, `auth`, `thread watch`, and the thread-record commands instead
start a backend: the CLI execs a sibling `delta-app` and talks to it over a Unix
socket. Without that binary the CLI fails with
`failed to start …/delta-app: No such file or directory`. Upstream ships
`delta-app` as a 300 MB GUI binary, and it is what dominates this package's size
(~385 MiB closure, of which ~330 MiB is these two binaries). The GUI libraries it
does not link against at load time are not pulled in.

Nix manages this install, so Delta's self-updater is disabled:
`DELTA_UPDATE_EXPLANATION` is set and the release is pinned in `releases.json`.
Upgrade by updating the flake input, not with `delta update`.

## Layout

- `flake.nix` — package outputs, per-system
- `package.nix` — the derivation
- `releases.json` — pinned upstream release: version, tarball URL, sha256

To bump: replace `releases.json` with the current
[upstream manifest](https://github.com/zed-industries/delta-nix/blob/main/releases.json)
and rebuild. The tarball URL and hash are read from it, so nothing else changes.

## Notes

- Linux only (`x86_64-linux`, `aarch64-linux`) — the upstream release assets are
  Linux binaries; there is no macOS package here.
- Files must keep LF line endings; a CRLF `package.nix` fails inside the Nix
  builder with `$'\r': command not found`. `.gitattributes` enforces this.
- Delta's auth state lives in the user's home (`~/.local/share/delta`,
  `~/.cache/delta-ipc`), not in the store. Sign in once with
  `delta auth login`.
