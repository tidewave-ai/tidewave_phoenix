{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
  };

  outputs = {
    nixpkgs,
    elixir-overlay,
    ...
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;
    forAllSystems = f:
      genAttrs flakeExposed (system:
        f (import nixpkgs {
          inherit system;
          overlays = [elixir-overlay.overlays.default];
        }));
  in {
    devShells = forAllSystems (pkgs: let
      inherit (pkgs) mkShell;
      inherit (pkgs.beam.interpreters) erlang_28;
    in {
      default = mkShell {
        name = "tidewave-phoenix";
        packages = with pkgs;
          [(elixir-with-otp erlang_28)."1.18.4" erlang_28]
          ++ lib.optional stdenv.isLinux [inotify-tools];
      };
    });

    packages = forAllSystems (pkgs: let
      inherit (pkgs.beam.interpreters) erlang_28;
      elixir = (pkgs.elixir-with-otp erlang_28)."1.18.4";

      tidewave = pkgs.stdenv.mkDerivation {
        name = "tidewave";
        version = "0.3.0";
        src = ./.;

        nativeBuildInputs = [elixir erlang_28];
        buildInputs = [elixir erlang_28];

        buildPhase = ''
          export MIX_ENV=prod
          export HEX_HOME=$TMPDIR/hex
          export MIX_HOME=$TMPDIR/mix

          mix local.hex --force
          mix local.rebar --force
          mix deps.get --only prod
          mix compile
        '';

        installPhase = ''
          mkdir -p $out/lib/tidewave
          cp -r _build/prod/lib/tidewave/ebin $out/lib/tidewave/
          cp -r deps $out/lib/

          mkdir -p $out/bin
          cat > $out/bin/tidewave <<EOF
          #!${pkgs.bash}/bin/bash
          export ERL_LIBS="$out/lib:\$ERL_LIBS"
          exec ${elixir}/bin/elixir -S mix tidewave
          EOF
          chmod +x $out/bin/tidewave
        '';

        meta = with pkgs.lib; {
          description = "Tidewave for Phoenix";
          homepage = "https://tidewave.ai/";
          license = licenses.asl20;
          maintainers = with maintainers; [zoedsoupe];
        };
      };
    in {
      default = tidewave;
    });
  };
}
