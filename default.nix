{ pkgs ? import <nixpkgs> {} }:

let
qtModules = with pkgs.qt6; [
  qtbase
  qtdeclarative
  qtmultimedia
];
qmlImportPath = pkgs.lib.concatMapStringsSep ":" (m: "${m}/lib/qt-6/qml") qtModules;
qtPluginPath  = pkgs.lib.concatMapStringsSep ":" (m: "${m}/lib/qt-6/plugins") qtModules;

nusgmonPython = pkgs.python3.withPackages (ps: [ ps.psutil ]);
scriptsPython = pkgs.python3.withPackages (ps: [ ps.holidays ]);

nusgmon = pkgs.stdenv.mkDerivation {
  pname = "nusgmon";
  version = "unstable-2024";
  src = pkgs.fetchFromGitHub {
    owner = "LUCKYS1NGHH";
    repo = "nusgmon";
    rev = "a896594";
    sha256 = "sha256-WTJ/jr+MawJsSIXAGi7itEo8/QJ54Po4FJ2ASw8/64Q=";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/share/nusgmon
    cp -r . $out/share/nusgmon

    makeWrapper ${nusgmonPython}/bin/python3 $out/bin/nusgmon \
      --add-flags "$out/share/nusgmon/nusgmon"

    install -Dm644 config.toml $out/share/nusgmon/config.toml.example
  '';
};

   runtimeDeps = with pkgs; [
     cava
     quickshell
     cliphist
     brightnessctl
     wl-clipboard
     inotify-tools
     pipewire
     pulseaudio
     blueman
     awww
     nusgmon
   ];
in
pkgs.stdenv.mkDerivation rec {
  pname = "chillpill-shell";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    makeWrapper
  ];

  buildInputs = with pkgs; [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qttools
    qt6.qtmultimedia
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_LIBDIR=lib"
  ];

  installPhase = ''
    runHook preInstall

    cmake --install .

    install -Dm755 $src/launcher.sh $out/bin/chillpill-shell
    substituteInPlace $out/bin/chillpill-shell \
      --replace '/usr/share/chillpill-shell' "$out/share/chillpill-shell" \
      --replace '$HOME/.config/quickshell/chillpill-shell/IslandBackend' "$out/lib/qt6/qml/IslandBackend"

    cat > $out/bin/chillpill-shell-ipc <<'WRAPPER'
  #!/usr/bin/env bash
  exec REPLACE_QS ipc -p REPLACE_CONFIG_PATH "$@"
  WRAPPER
    chmod +x $out/bin/chillpill-shell-ipc
    substituteInPlace $out/bin/chillpill-shell-ipc \
      --replace REPLACE_QS "${pkgs.quickshell}/bin/qs" \
      --replace REPLACE_CONFIG_PATH "$out/share/chillpill-shell"

    mkdir -p $out/share/chillpill-shell
    cp -r $src/qml/*   $out/share/chillpill-shell/
    cp -r $src/share   $out/share/chillpill-shell/
    cp -r $src/scripts $out/share/chillpill-shell/
    install -Dm644 $src/config.jsonc $out/share/chillpill-shell/config.jsonc.example

    chmod +x $out/share/chillpill-shell/scripts/*
    PATH="${scriptsPython}/bin:$PATH" patchShebangs $out/share/chillpill-shell/scripts

    grep -rl '/usr/share/chillpill-shell' $out/share/chillpill-shell | while read -r f; do
      substituteInPlace "$f" --replace '/usr/share/chillpill-shell' "$out/share/chillpill-shell"
    done

    install -Dm644 $src/chillpill.desktop $out/share/applications/chillpill.desktop
    substituteInPlace $out/share/applications/chillpill.desktop \
      --replace 'Exec=chillpill-shell' "Exec=$out/bin/chillpill-shell"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/chillpill-shell \
      --set QML_IMPORT_PATH "$out/share/chillpill-shell:$out/lib/qt6/qml:${qmlImportPath}" \
      --set QT_PLUGIN_PATH "${qtPluginPath}" \
      --set LD_LIBRARY_PATH "$out/lib/qt6/qml/IslandBackend" \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

  meta = with pkgs.lib; {
    description = "ChillPill (Wayland bar) fork - chillpill-shell";
    homepage = "https://github.com/PinguinAdvokat/chillpill-shell";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "chillpill-shell";
  };
}
