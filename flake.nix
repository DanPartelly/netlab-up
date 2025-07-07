{
  description = "Netlab: Making virtual networking labs suck less ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    ...
  }: let
    system = "x86_64-linux";
    
    importPkgs = nixpkgs: import nixpkgs {
      config.allowUnfree = true;
      inherit system;
    };
    
    pkgs = importPkgs nixpkgs;
    pkgs-unstable = importPkgs nixpkgs-unstable;

    # Common netlab package definition
    netlab = pkgs.python3Packages.buildPythonPackage rec {
      pname = "netlab";
      version = "25.06";
      format = "setuptools";

      src = pkgs.fetchFromGitHub {
        owner = "ipspace";
        repo = "netlab";
        rev = "release_25.06";
        sha256 = "sha256-ORxi5Df1dYQAwNqQgBmpFZXPRiq24wh/DY6YkwSxPco=";
      };

      propagatedBuildInputs = with pkgs.python3Packages; [
        jinja2
        pyyaml
        netaddr
        python-box
        importlib-resources
        typing-extensions
        filelock
        packaging
        rich
      ];

      postPatch = ''
        patchShebangs .
      '';

      doCheck = false;
    };

    # Common Python environment
    pythonEnv = pkgs.python3.withPackages (ps: [
      netlab
      ps.ansible-core
      ps.ansible-pylibssh
    ]);

    # Common bundled tools
    bundledTools = with pkgs; [
      iproute2
      bridge-utils
      vagrant
      sshpass
      graphviz
      yamllint
      jq
      pkgs-unstable.containerlab
    ];
  in {
    packages.x86_64-linux = {
      default = pkgs.stdenv.mkDerivation {
        name = "netlab-with-tools";

        unpackPhase = "true";

        installPhase = ''
          mkdir -p $out/bin

          # Copy all binaries from bundled tools
          ${pkgs.lib.concatMapStringsSep "\n" (
            tool: "cp -r ${tool}/bin/* $out/bin/ 2>/dev/null || true"
          )
          bundledTools}

          # Copy other directories from bundled tools
          ${pkgs.lib.concatMapStringsSep "\n" (tool: ''
            for dir in share lib libexec etc; do
              if [[ -d "${tool}/$dir" ]]; then
                mkdir -p "$out/$dir"
                cp -r ${tool}/$dir/* "$out/$dir/" 2>/dev/null || true
              fi
            done
          '')
          bundledTools}

          # Create wrappers for Python executables that need proper environment
          for cmd in netlab ansible ansible-playbook ansible-galaxy ansible-config ansible-console ansible-doc ansible-inventory ansible-pull ansible-vault; do
            if [[ -f "${pythonEnv}/bin/$cmd" ]]; then
              cat > "$out/bin/$cmd" << EOF
#!/usr/bin/env bash
exec ${pythonEnv}/bin/$cmd "\$@"
EOF
              chmod +x "$out/bin/$cmd"
            fi
          done
        '';

        meta = {
          description = "Netlab with all dependencies and tools";
          platforms = pkgs.lib.platforms.linux;
        };
      };
    };

    # Development shell using the same common definitions
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [pythonEnv] ++ bundledTools;

      shellHook = ''
        export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH"
        export PATH="${pythonEnv}/bin:$PATH"
        echo "Netlab environment ready!"
        echo "Available commands: netlab, ansible, ansible-playbook, containerlab"
        echo "ansible-pylibssh is available for improved SSH performance"
      '';
    };
  };
}
