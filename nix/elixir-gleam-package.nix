{ pkgs, beamPackages, src }:
  pkgs.stdenv.mkDerivation rec {
    pname = "elixir-gleam";
    version = "1.20.0-dev-gleam";

    inherit src;

    buildInputs = [ beamPackages.erlang ];
    nativeBuildInputs = [ pkgs.makeWrapper pkgs.coreutils pkgs.bash ];

    preBuild = ''
      export PATH="${pkgs.coreutils}/bin:$PATH"
      find . -name "*.escript" -exec sed -i "1s|#!/usr/bin/env|#!${pkgs.coreutils}/bin/env|" {} \;
    '';

    makeFlags = [ "Q=" ];

    installPhase = ''
      make install PREFIX=$out

      for binary in elixir elixirc iex mix; do
        if [ -f "$out/bin/$binary" ]; then
          wrapProgram "$out/bin/$binary" \
            --prefix PATH : "${beamPackages.erlang}/bin:${pkgs.coreutils}/bin" \
            --set ERL_LIBS "$out/lib"
        fi
      done
    '';

    meta = with pkgs.lib; {
      description = "Elixir 1.20-dev with native Gleam compiler support";
      homepage = "https://github.com/elixir-lang/elixir";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  }
