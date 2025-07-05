{
  description = "Netlab: Making virtual networking labs suck less ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    packages.x86_64-linux = let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        config = {
          allowUnfree = true;
        };
        inherit system;
      };

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
          ansible-core
        ];

        postPatch = ''
          patchShebangs .
        '';

        doCheck = false;
      };

      pythonEnv = pkgs.python3.withPackages (ps: [
        netlab
        ps.ansible-core
      ]);

      bundledTools = with pkgs; [
        glibcLocales
        iproute2
        bridge-utils
        containerlab
        vagrant
        sshpass
        graphviz
      ];

      netlab-with-tools = pkgs.stdenv.mkDerivation {
        name = "netlab-with-tools";

        unpackPhase = "true";

        installPhase = ''
                    mkdir -p $out/bin

                    cat > $out/bin/netlab << 'EOF'
          #!/usr/bin/env bash
          export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH"
          exec ${pythonEnv}/bin/netlab "$@"
          EOF
                    chmod +x $out/bin/netlab

                    cat > $out/bin/ansible << 'EOF'
          #!/usr/bin/env bash
          export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH"
          exec ${pythonEnv}/bin/ansible "$@"
          EOF
                    chmod +x $out/bin/ansible

                    cat > $out/bin/ansible-playbook << 'EOF'
          #!/usr/bin/env bash
          export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH"
          exec ${pythonEnv}/bin/ansible-playbook "$@"
          EOF
                    chmod +x $out/bin/ansible-playbook

                    cat > $out/bin/ansible-galaxy << 'EOF'
          #!/usr/bin/env bash
          export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH"
          exec ${pythonEnv}/bin/ansible-galaxy "$@"
          EOF
                    chmod +x $out/bin/ansible-galaxy

                    for cmd in ansible-config ansible-console ansible-doc ansible-inventory ansible-pull ansible-vault; do
                      if [[ -f "${pythonEnv}/bin/$cmd" ]]; then
                        cat > "$out/bin/$cmd" << EOF
          #!/usr/bin/env bash
          export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:\$PYTHONPATH"
          exec ${pythonEnv}/bin/$cmd "\$@"
          EOF
                        chmod +x "$out/bin/$cmd"
                      fi
                    done

                    ${pkgs.lib.concatMapStringsSep "\n" (
              tool: "cp -r ${tool}/bin/* $out/bin/ 2>/dev/null || true"
            )
            bundledTools}

                    ${pkgs.lib.concatMapStringsSep "\n" (tool: ''
              for dir in share lib libexec etc; do
                if [[ -d "${tool}/$dir" ]]; then
                  mkdir -p "$out/$dir"
                  cp -r ${tool}/$dir/* "$out/$dir/" 2>/dev/null || true
                fi
              done
            '')
            bundledTools}
        '';

        meta = {
          description = "Netlab with all dependencies and tools";
          platforms = pkgs.lib.platforms.linux;
        };
      };
    in {
      default = netlab-with-tools;
    };

    # Also provide a development shell
    devShells.x86_64-linux.default = let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        config = {
          allowUnfree = true;
        };
        inherit system;
      };

      # Same netlab package as above
      netlab = pkgs.python3Packages.buildPythonPackage rec {
        pname = "netlab";
        version = "25.06";

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
          ansible-core
        ];

        postPatch = ''
          patchShebangs .
        '';

        doCheck = false;
      };

      pythonEnv = pkgs.python3.withPackages (ps: [
        netlab
        ps.ansible-core
      ]);

      bundledTools = with pkgs; [
        glibcLocales
        iproute2
        bridge-utils
        containerlab
        vagrant
        sshpass
        graphviz
      ];
    in
      pkgs.mkShell {
        buildInputs = [pythonEnv] ++ bundledTools;

        shellHook = ''
          export PYTHONPATH="${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH"
          export PATH="${pythonEnv}/bin:$PATH"
          echo "Netlab environment ready!"
          echo "Available commands: netlab, ansible, ansible-playbook, containerlab"
        '';
      };
  };
}
