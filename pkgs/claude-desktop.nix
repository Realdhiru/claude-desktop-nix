{ lib, stdenv, fetchurl, dpkg, buildFHSEnv, writeShellScript, symlinkJoin
, gtk3, libnotify, nss, nspr, at-spi2-core, at-spi2-atk, atk, libdrm, mesa, libgbm, libGL
, vulkan-loader, alsa-lib, cairo, cups, dbus, expat, gdk-pixbuf, glib
, pango, openssl, systemd, libusb1, libxkbcommon, zlib, fontconfig
, libx11, libxcb, libxcomposite, libxdamage, libxext, libxfixes, libxrandr
, xdg-utils, wayland, pipewire, libva, libdecor, libpulseaudio
, bubblewrap, socat, qemu, OVMF, virtiofsd, gnome-keyring, libsecret
, withCowork ? false
}:

let
  version = "4.29.0";
  debFile = "pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/${debFile}";
    hash = "sha256-SqD3Y9bAWseVAjkt1Q9df1xFWy8KQF1b3xVUrNg0Kok=";
  };

  unpacked = stdenv.mkDerivation {
    pname = "claude-desktop-data";
    inherit version src;
    dontUnpack = true;
    nativeBuildInputs = [ dpkg ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf - -C $out
      runHook postInstall
    '';
  };

  launch = writeShellScript "claude-desktop-launch" ''
    export NIXOS_OZONE_WL=1
    export ELECTRON_OZONE_PLATFORM_HINT=wayland
    export OZONE_PLATFORM_HINT=wayland
    export GDK_BACKEND=wayland,x11
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    export SDL_VIDEODRIVER=wayland
    export CLUTTER_BACKEND=wayland
    export XCURSOR_THEME=''${XCURSOR_THEME:-Adwaita}
    export XCURSOR_SIZE=''${XCURSOR_SIZE:-24}
    export XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    exec ${unpacked}/usr/lib/claude-desktop/claude-desktop \
      --ozone-platform=wayland \
      --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer \
      --ozone-platform-hint=wayland \
      --enable-wayland-ime \
      "$@"
  '';

  fhs = buildFHSEnv {
    name = "claude-desktop-fhs";
    executableName = "claude-desktop";
    runScript = launch;
    targetPkgs = p: with p; [
      gtk3 libnotify nss nspr at-spi2-core at-spi2-atk atk libdrm mesa libgbm libGL
      vulkan-loader alsa-lib cairo cups dbus expat gdk-pixbuf glib
      pango openssl systemd libusb1 libxkbcommon zlib stdenv.cc.cc fontconfig
      libx11 libxcb libxcomposite libxdamage libxext libxfixes libxrandr
      xdg-utils wayland pipewire libva libdecor libpulseaudio libsecret
      bubblewrap socat gnome-keyring
    ] ++ lib.optionals withCowork [ qemu OVMF virtiofsd ];
  };
in
symlinkJoin {
  name = "claude-desktop-${version}";
  paths = [ fhs ];
  postBuild = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor
    cp ${unpacked}/usr/share/applications/com.anthropic.Claude.desktop \
      $out/share/applications/com.anthropic.Claude.desktop
    cp -r ${unpacked}/usr/share/icons/hicolor/* $out/share/icons/hicolor/
    substituteInPlace $out/share/applications/com.anthropic.Claude.desktop \
      --replace-fail 'Exec=claude-desktop ' 'Exec=${fhs}/bin/claude-desktop '
  '';
  meta = with lib; {
    description = "Anthropic's official Claude Desktop Linux beta (FHS-wrapped, native Wayland)";
    homepage = "https://claude.ai/download";
    downloadPage = "https://support.claude.com/en/articles/10065433-install-claude-desktop";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
}
