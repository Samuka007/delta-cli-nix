{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  patchelf,
  glibc,
  xcb-util-cursor,
  libxcb,
  libxkbcommon,
  libunwind,
  release,
  asset,
  platform ? stdenv.hostPlatform.system,
}:

# Only the `delta` CLI ships here: the desktop app (`delta-app`), icons, and
# .desktop entries from the upstream tarball are dropped on purpose.
#
# The CLI is not self-sufficient for every subcommand: `thread`/`worktree` talk
# to the server directly, but `org`, `auth`, `thread watch` and friends start a
# windowless backend by exec'ing a sibling `delta-app`. That binary is bundled
# because the CLI resolves it next to itself and refuses the request otherwise
# (verified: `org current` fails with "failed to start .../delta-app").
stdenv.mkDerivation {
  pname = "delta-cli";
  version = release.version;

  src = fetchurl {
    url = "https://github.com/zed-industries/delta-nix/releases/download/${release.tag}/${asset.filename}";
    hash = asset.hash;
  };

  sourceRoot = "Delta";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    glibc
    libxcb
    libxkbcommon
    libunwind
    (lib.getLib stdenv.cc.cc)
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  # The bundle ships its own X/xkb libs built against an older glibc; Nix ones
  # are newer and ABI-compatible, so keep the store copies and drop the vendored
  # ones from the install tree. libunwind stays bundled: upstream keeps its own
  # ahead of Nix libs on purpose.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/delta
    install -m755 bin/delta $out/bin/delta
    install -m755 bin/delta-app $out/lib/delta/delta-app
    install -m644 lib/libunwind.so.1 $out/lib/delta/libunwind.so.1

    runHook postInstall
  '';

  postFixup = ''
    # The CLI execs `delta-app` from its own directory; give it a sibling without
    # duplicating the 300MB binary into $out/bin.
    ln -s ../lib/delta/libunwind.so.1 $out/lib/libunwind.so.1

    makeWrapper $out/lib/delta/delta-app $out/bin/delta-app \
      --prefix LD_LIBRARY_PATH : "$out/lib/delta"

    wrapProgram $out/bin/delta \
      --prefix LD_LIBRARY_PATH : "$out/lib/delta" \
      --set DELTA_UPDATE_EXPLANATION \
      "Delta is managed by Nix; update your flake input to install a newer release."
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/delta --help | grep -q 'Delta CLI'
    $out/bin/delta --version | grep -q '${release.version}'
    $out/bin/delta --json thread contract | grep -q '"operation":"contract"'
    runHook postInstallCheck
  '';

  meta = {
    description = "Delta CLI for recording agent sessions into Delta threads (CLI and windowless backend only)";
    homepage = "https://delta.dev";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    mainProgram = "delta";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
