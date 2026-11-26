# Homebridge plugin that wakes a Synology NAS, shuts it down and reads its temperature.
{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage (finalAttrs: {
  pname = "homebridge-synology";
  version = "0.5.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/homebridge-synology/-/homebridge-synology-${finalAttrs.version}.tgz";
    hash = "sha256-p2dh08SwQghx2XzMZjipMiWBQLqUelmUI6upPDYe+1M=";
  };

  # The tarball of the registry has none.
  postPatch = "cp ${./package-lock.json} package-lock.json";
  npmDepsHash = "sha256-KcyAHvDetXngP0jNMA/Ht4pILiLakQuSy7sLpRxwceo=";
  # npm unpacks the syno fork, a git dependency, inside its cache.
  makeCacheWritable = true;
  dontNpmBuild = true;

  meta = {
    description = "Control your Synology Diskstation with Homekit";
    homepage = "https://github.com/stfnhmplr/homebridge-synology";
    license = lib.licenses.mit;
  };
})
