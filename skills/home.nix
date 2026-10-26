{ lib, pkgs, ... }:
let
  manifest = builtins.fromJSON (builtins.readFile ./manifest.json);
  enabled = builtins.filter (skill: skill.enabled) manifest.skills;
  # One immutable canonical library; only discovery paths differ. Do not link
  # entire runtime directories, which also contain credentials and local state.
  library = ./library;
  locations = [ ".agents/skills" ".claude/skills" ];
  links = lib.concatMap (skill: map (location: {
    name = "${location}/${skill.name}";
    value.source = "${library}/${skill.name}";
  }) locations) enabled;
in
assert manifest.schema == 1;
assert builtins.length manifest.skills == builtins.length (lib.unique (map (s: s.name) manifest.skills));
assert lib.all (s: builtins.match "[a-z0-9]+(-[a-z0-9]+)*" s.name != null && builtins.stringLength s.name <= 64) manifest.skills;
{
  home.file = builtins.listToAttrs links;
  home.packages = [ (pkgs.writeShellScriptBin "handoff" ''
    exec ${pkgs.python3}/bin/python3 ${library}/resume-task/scripts/handoff.py "$@"
  '') ];
}
