{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nurpkgs.url = "github:mbekkomo/nurpkgs";
    nurpkgs.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      nurpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nur = nurpkgs.packages.${system};
        
        lbuffer = pkgs.lua54Packages.buildLuaPackage {
          pname = "lbuffer";
          version = "0.0.0";
        
          propagateBuildInputs = [ nur.plutolang ];

          buildPhase = ''
            cc -shared -fPIC -o buffer.so *.c -L${nur.plutolang.dev}/lib -I${nur.plutolang.dev}/include -lplutostatic
          '';

          installPhase = ''
            mkdir -p $out/lib/lua/5.4
            install -Dm755 -t $out/lib/lua/5.4 buffer.so
          '';
        };
        lua-miniz = pkgs.lua54Packages.buildLuaPackage {
          pname = "lua-miniz";
          version = "0.0.0";
          
          propagateBuildInputs = [ nur.plutolang ];

          buildPhase = ''
            cc -shared -fPIC -o miniz.so lminiz.c -L${nur.plutolang.dev}/lib -I${nur.plutolang.dev}/include -lplutostatic
          '';

          installPhase = ''
            mkdir -p $out/lib/lua/5.4
            install -Dm755 -t $out/lib/lua/5.4 miniz.so
          '';
        };

        luaCLib = ver: deriv: "${deriv}/lib/lua/${ver}/?.so";
      in
      rec {
        packages.luabc = pkgs.stdenv.mkDerivation {
          pname = "luabc";
          version = "0.1.0";

          src = ./.;

          buildInputs = [
            lbuffer
            lua-miniz
          ];

          buildPhase = ''
            # LUA_PATH=$PWD/src pluto src/main.pluto \
            #   src/main.pluto \
            #   --lua $(command -v pluto) \
            #   --include-dir src \
            #   --output luabc
          '';

          installPhase = ''
            mkdir -p $out/bin
            install -Dm755 -t $out/bin luabc
          '';
        };

        packages.default = packages.luabc;

        devShells.default = pkgs.mkShell {
          packages = [
            lbuffer
            lua-miniz
            nur.plutolang
          ];

          shellHook = ''
            export LUA_CPATH=";;${luaCLib "5.4" lbuffer};${luaCLib "5.4" lua-miniz}"
          '';
        };
      }
    );
}
