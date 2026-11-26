# Asks for a password and prints its hash as my.homebridge reads it from sops:
# <iterations>:<salt>:<hash>, the PBKDF2-SHA512 of homebridge-config-ui-x.
{
  writeShellApplication,
  nodejs,
}:
writeShellApplication {
  name = "homebridge-password-hash";
  runtimeInputs = [ nodejs ];
  text = ''
    IFS= read -rsp "Password: " password || [ -n "$password" ]
    echo >&2
    IFS= read -rsp "Password again: " again || [ -n "$again" ]
    echo >&2
    if [ "$password" != "$again" ]; then
      echo "The two passwords differ." >&2
      exit 1
    fi
    printf %s "$password" | node -e '
      const { pbkdf2Sync, randomBytes } = require("node:crypto");
      const password = require("node:fs").readFileSync(0, "utf8");
      const iterations = 210000;
      const salt = randomBytes(32).toString("hex");
      const hash = pbkdf2Sync(password, salt, iterations, 64, "sha512").toString("hex");
      console.log([iterations, salt, hash].join(":"));
    '
  '';
}
