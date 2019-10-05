{ pkgs, config, lib, ... }: with lib; let
  #inherit (config.ci.env.bootstrap) pkgs;
  filterEmpty = filterAttrs (_: v: v != null && v != { } && v != [ ]);
  cfg = config.gh-actions;
  containerType = types.submodule ({ name, ... }: {
    options = {
      image = mkOption {
        # TODO: submodule for version spec?
        type = types.str;
        default = name;
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      ports = mkOption {
        # TODO: submodule? can be ints, or "1234/tcp"
        type = types.listOf types.str;
        default = [ ];
      };
      volumes = mkOption {
        # TODO: submodule for this? can be /src:/dst or src_name:/dst or /sameSrcDst
        type = types.listOf types.str;
        default = [ ];
      };
      options = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  });
  actionType = types.submodule ({ config, ... }: {
    options = {
      owner = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      repo = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      slug = mkOption {
        type = types.nullOr types.str;
      };
      path = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      version = mkOption {
        type = types.str;
        default = "v1";
      };
      spec = mkOption {
        type = types.str;
      };
      docker = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };

    config = {
      slug = mkOptionDefault (
        if config.repo != null then "${config.owner}/${config.repo}" else null);
      spec = mkOptionDefault (
        if config.docker != null then "docker://${config.docker}"
        else if config.repo == null then config.path
        else "${config.slug}${optionalString (config.path != null) "/${config.path}"}@${config.version}");
    };
  });
  stepType = { isList }: types.submodule ({ name, config, ... }: {
    options = {
      id = mkOption {
        type = types.nullOr types.str;
        default = if isList then null else name;
      };
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      order = mkOption {
        type = types.int;
        default = 1000;
      };
      "if" = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      uses = mkOption {
        type = types.nullOr actionType;
        default = null;
      };
      run = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      shell = mkOption {
        type = types.nullOr (types.enum [ "bash" "pwsh" "python" "sh" "cmd" "powershell" ]);
        default = null;
        example = "bash";
      };
      "with" = mkOption {
        # TODO: abstract this away into an action option type
        # TODO: with.entrypoint and with.args are special?
        type = types.attrsOf types.unspecified;
        default = { };
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      working-directory = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      continue-on-error = mkOption {
        type = types.bool;
        default = false;
      };
      timeout-minutes = mkOption {
        type = types.nullOr types.int;
        default = null;
      };
      shellTemplate = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "-xeu {0} scriptArg";
      };
    };
  });
  jobType = types.submodule ({ name, config, ... }: let
    sortedSteps = steps: foldl' (list: step: let
      prev = if list == [] then { order = 1000; } else last list;
      order = /*if prev.id or null != null
        then config.step.${prev.id}.order
        else*/ prev.order;
    in list ++ singleton ({
      order = mkDefault (order + 10);
    } // step)) [] steps;
  in {
    options = {
      id = mkOption {
        type = types.str;
        default = name;
      };
      name = mkOption {
        type = types.str;
        default = config.id;
      };
      needs = let
        type = types.listOf types.str;
        fudge = types.coercedTo types.str singleton type;
      in mkOption {
        type = fudge;
        default = [ ];
      };
      runs-on = mkOption {
        type = types.enum [
          "ubuntu-latest" "ubuntu-18.04" "ubuntu-16.04"
          "windows-latest" "windows-2019" "windows-2016"
          "macOS-latest" "macOS-10.14"
        ];
        default = "ubuntu-latest";
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      "if" = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      steps = mkOption {
        type = types.listOf (stepType { isList = true; });
        default = [ ];
      };
      step = mkOption {
        type = types.attrsOf (stepType { isList = false; });
        default = { };
      };
      timeout-minutes = mkOption {
        type = types.int;
        default = 360;
      };
      strategy = {
        # TODO: complicated!
        matrix = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
        fail-fast = mkOption {
          type = types.bool;
          default = true;
        };
        max-parallel = mkOption {
          type = types.nullOr types.int;
          default = null;
        };
      };
      container = mkOption {
        type = types.nullOr containerType;
        default = null;
      };
      services = mkOption {
        type = types.attrsOf containerType;
        default = { };
      };
    };

    config.step = let
      steps = sortedSteps config.steps;
    in foldl' (steps: s: steps // {
      ${if s.id or null != null then s.id else "step${toString (length (attrNames steps))}"} = s;
    }) { } steps;
  });
in {
  options.gh-actions = {
    enable = mkEnableOption "GitHub Actions";
    name = mkOption {
      type = types.str;
    };
    on = mkOption {
      # TODO: proper types here
      type = types.unspecified;
      default = [ "push" "pull_request" ];
    };
    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
    };
    jobs = mkOption {
      type = types.attrsOf jobType;
      default = { };
    };
    configFile = mkOption {
      type = types.package;
      internal = true;
    };
  };
  config.gh-actions = mkIf config.gh-actions.enable {
    configFile = pkgs.stdenvNoCC.mkDerivation {
      name = "gh-actions.yml";
      preferLocalBuild = true;
      allowSubstitutes = false;
      nativeBuildInputs = with pkgs; [ yq ];
      data = builtins.toJSON (filterEmpty {
        inherit (cfg) name on env;
        jobs = mapAttrs' (_: j: nameValuePair j.id (filterEmpty {
          inherit (j) name needs runs-on env "if";
          ${if j.timeout-minutes != 360 then "timeout-minutes" else null} = j.timeout-minutes;
          steps = map (s: filterEmpty {
            inherit (s) id name "if" run shell "with" env working-directory timeout-minutes shellTemplate;
            ${if s.uses != null then "uses" else null} = s.uses.spec;
            ${if s.continue-on-error then "continue-on-error" else null} = s.continue-on-error;
          }) (sort (l: r: l.order < r.order) (attrValues j.step));
        } // optionalAttrs (j.strategy.matrix != { }) {
          matrix = filterEmpty {
            inherit (j.strategy) matrix max-parallel;
            ${if !s.fail-fast then "fail-fast" else null} = j.strategy.fail-fast;
          };
        } // optionalAttrs (j.container != null) {
          container = filterEmpty {
            inherit (j.container) image env ports volumes options;
          };
        } // optionalAttrs (j.services != { }) {
          services = mapAttrs (_: s: filterEmpty {
            inherit (s) image env ports volumes options;
          }) j.services;
        })) cfg.jobs;
      });
      passAsFile = [ "data" "buildCommand" ];
      buildCommand = ''
        yq --yaml-output -c . $dataPath > $out
      '';
    };
  };
}
