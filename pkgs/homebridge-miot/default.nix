# Homebridge plugin for Xiaomi miot devices, the Dreame vacuums among them.
{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage (finalAttrs: {
  pname = "homebridge-miot";
  version = "2.2.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/homebridge-miot/-/homebridge-miot-${finalAttrs.version}.tgz";
    hash = "sha256-MNIBN/+RqHyvTn2eeSRk7kGWHN4YWEYP1Se8PUJLQqE=";
  };

  # The tarball of the registry has none.
  postPatch = "cp ${./package-lock.json} package-lock.json";
  npmDepsHash = "sha256-DlyIZXu9LIQjDN175QaHYHbu4EePpqEorLwsTg9r5SM=";
  dontNpmBuild = true;

  meta = {
    description = "Homebridge plugin for devices supporting the miot protocol";
    homepage = "https://github.com/merdok/homebridge-miot";
    license = lib.licenses.mit;
  };
})
