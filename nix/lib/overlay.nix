{ config, modulesPath, libPath, configPath, rootConfigPath, ... }: self: super: with super.lib; {
  ci = super.ci.extend (cself: csuper: {
    inherit config;

    doc = let
      inherit (config._module.args.channels) nmd;
      inherit (config.channels.ci) name;
      scrubPkgs = {
        channels = mapAttrs (k: c: {
          import = mkForce (nmd.scrubDerivations (if k == "nixpkgs" then "pkgs" else k) config.channels.${k}.import);
        }) config.channels;
        nixpkgs.import = mkForce (nmd.scrubDerivations "pkgs" config.nixpkgs.import);
        lib.ci = {
          import = mkForce builtins.import;
          nixPathImport = mkForce (path: builtins.import);
        };
        _module.args = {
          inherit modulesPath libPath configPath rootConfigPath;
        };
      };
      options = nmd.buildModulesDocs {
        modules = import ../modules.nix { } ++ [ scrubPkgs ];
        moduleRootPaths = [ modulesPath ];
        mkModuleUrl = path: "https://github.com/arcnmx/ci/blob/${config.ci.version}/nix/${path}#blob-path";
        channelName = name;
        docBook.id = "${name}-options";
      };
      docs = nmd.buildDocBookDocs {
        pathName = name;
        modulesDocs = [ options ];
        documentsDirectory = ../doc;
        chunkToc = ''
          <toc>
            <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-${name}-manual">
              <?dbhtml filename="index.html"?>
              <d:tocentry linkend="ch-options"><?dbhtml filename="options.html"?></d:tocentry>
              <d:tocentry linkend="ch-env"><?dbhtml filename="env.html"?></d:tocentry>
            </d:tocentry>
          </toc>
        '';
      };
    in {
      json = docs.json.override {
        path = "share/doc/${name}/options.json";
      };

      manPages = docs.manPages;

      manual = docs.html;

      open = docs.htmlOpenTool;
    };
  });
}
