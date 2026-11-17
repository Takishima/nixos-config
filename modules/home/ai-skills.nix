# Renders <root>/<area>/<name>/{meta.nix, body.md, ...} trees into ~/.claude/skills.
{
  config,
  lib,
  ...
}:
let
  cfg = config.my.aiSkills;

  subdirs =
    dir: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

  discover =
    root:
    lib.concatMap (
      area:
      map (name: rec {
        inherit name area;
        dir = "${root}/${area}/${name}";
        meta = import "${dir}/meta.nix";
      }) (subdirs "${root}/${area}")
    ) (subdirs root);

  wanted =
    skill:
    (cfg.areas == null || lib.elem skill.area cfg.areas)
    && !lib.elem skill.name cfg.exclude
    # meta.enable tests an option of the source repository.
    && !(skill.meta ? enable);

  skills = lib.filter wanted (lib.concatMap discover cfg.roots);

  # Bodies carry @{token} placeholders; unknown ones are dropped.
  tokens = {
    ask_user = "AskUserQuestion";
    file_list_tools = "Glob/LS";
    spawn_subagent = "Use the Task tool with the appropriate subagent_type and model parameters";
  };
  substitute =
    text:
    lib.concatStrings (
      lib.filter lib.isString (
        builtins.split "@\\{[A-Za-z0-9_]+}" (
          lib.replaceStrings (map (t: "@{${t}}") (lib.attrNames tokens)) (lib.attrValues tokens) text
        )
      )
    );

  frontmatter =
    meta:
    lib.concatLines (
      [
        "---"
        "name: ${builtins.toJSON meta.name}"
        "description: ${builtins.toJSON meta.description}"
      ]
      ++ lib.optional (meta ? argumentHint) "argument-hint: ${builtins.toJSON meta.argumentHint}"
      ++ lib.optional (meta ? model) "model: ${meta.model}"
      ++ lib.optional (meta ? effort) "effort: ${meta.effort}"
      ++ lib.optional (meta.disableModelInvocation or false) "disable-model-invocation: true"
      ++ lib.optional (meta ? allowedTools) "allowed-tools: ${meta.allowedTools}"
      ++ lib.optional (meta ? context) "context: ${meta.context}"
      ++ [ "---" ]
    );

  reserved = [
    "meta.nix"
    "body.md"
    "variants.nix"
  ];
  supportingFiles =
    skill:
    lib.listToAttrs (
      lib.concatMap (
        file:
        let
          rel = builtins.unsafeDiscardStringContext (lib.removePrefix "${skill.dir}/" (toString file));
        in
        lib.optional (!lib.elem rel reserved) (
          lib.nameValuePair ".claude/skills/${skill.name}/${rel}" { source = file; }
        )
      ) (lib.filesystem.listFilesRecursive skill.dir)
    );
in
{
  options.my.aiSkills = {
    enable = lib.mkEnableOption "Claude Code skills rendered from skill trees";

    roots = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
      default = [ ];
      example = lib.literalExpression "[ ./skills ]";
      description = "Skill trees. A skill name may appear in one of them only.";
    };

    areas = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [
        "nix"
        "languages"
      ];
      description = "Areas to deploy; null deploys every area.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Skill names to leave out.";
    };

    names = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "The skills that end up deployed.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.allUnique cfg.names;
        message = "my.aiSkills: a skill name appears in several areas or roots: ${toString cfg.names}";
      }
    ];

    my.aiSkills.names = map (skill: skill.name) skills;

    programs.claude-code.skills = lib.listToAttrs (
      map (
        skill:
        lib.nameValuePair skill.name (
          frontmatter skill.meta + "\n" + substitute (builtins.readFile "${skill.dir}/body.md")
        )
      ) skills
    );

    home.file = lib.mkMerge (map supportingFiles skills);
  };
}
