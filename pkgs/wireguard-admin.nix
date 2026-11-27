# Manages the clients of a host's my.wireguard server from a checkout.
{
  lib,
  writeShellApplication,
  coreutils,
  jq,
  qrencode,
  sops,
  util-linux,
  wireguard-tools,

  host,
  # The host's config.my.wireguard.
  server,
}:
let
  inherit (server) subnet subnet6;
  port = toString server.port;
in
writeShellApplication {
  name = "wireguard-${host}";
  runtimeInputs = [
    coreutils
    jq
    qrencode
    sops
    util-linux
    wireguard-tools
  ];
  text = ''
    file=hosts/${host}/wireguard.json
    secrets=secrets/${host}.yaml
    prefix=${lib.removeSuffix ".0/24" subnet}

    usage() {
      cat <<EOF
    Usage: wireguard-${host} <command>

      init                      a new server: makes its key
      add <name> [--endpoint <public name>] [--public-key <key>] [-o <file>]
                                a new client; prints its configuration and QR code.
                                The endpoint defaults to wireguard/endpoint in
                                $secrets
      disable <name>            shuts a client out, and keeps its address and keys
      enable <name>
      local-network <name>      lets a client reach the server's local network too
      internet-only <name>      takes that back: the client reaches the internet only
      remove <name>
      rotate [-o <file>]        a new key for the server and a new preshared key for
                                every client; prints the two lines each client has
                                to change. The clients keep their key pairs
      list

    Run it at the root of the repository. It writes $file,
    and the keys that are secret to $secrets, which sops has
    to be able to decrypt (SOPS_AGE_KEY). Commit both files.
    EOF
    }

    die() {
      echo "wireguard-${host}: $*" >&2
      exit 1
    }

    command=''${1:-}
    [ $# -gt 0 ] && shift
    [ -z "$command" ] || [ -d "$(dirname "$file")" ] ||
      die "no $(dirname "$file") here: run it at the root of the repository"
    case $command in
      init | add | remove | rotate)
        sops decrypt "$secrets" >/dev/null || die "sops cannot decrypt $secrets: is SOPS_AGE_KEY set?"
        ;;
    esac

    state() {
      if [ -f "$file" ]; then cat "$file"; else echo '{"publicKey": null, "peers": {}}'; fi
    }
    save() {
      jq -S . >"$file.new"
      mv "$file.new" "$file"
    }
    has_client() {
      state | jq -e --arg name "$1" '.peers | has($name)' >/dev/null
    }
    server_key() {
      local key
      key=$(state | jq -r '.publicKey // empty')
      [ -n "$key" ] || die "$file has no server yet: run init"
      echo "$key"
    }
    existing_client() {
      [ -n "$1" ] || die "$command takes the client's name"
      has_client "$1" || die "no client $1"
    }
    sops_index() {
      jq -rn --arg path "wireguard/$1" '$path | split("/") | map("[" + tojson + "]") | join("")'
    }

    # secret <key under wireguard> <value>: kept until write_secrets, which
    # runs before anything else is written.
    pending=()
    secret() {
      pending+=("$1=$2")
    }
    drop_secret() {
      local index
      index=$(sops_index "$1")
      if sops decrypt --extract "$index" "$secrets" >/dev/null 2>&1; then
        sops unset "$secrets" "$index"
      fi
    }
    write_secrets() {
      [ ''${#pending[@]} -gt 0 ] || return 0
      local entry before
      before=$(mktemp)
      cp "$secrets" "$before"
      for entry in "''${pending[@]}"; do
        # printf is a shell builtin: the secret appears on no command line.
        printf %s "''${entry#*=}" | jq -Rs . |
          sops set --value-stdin "$secrets" "$(sops_index "''${entry%%=*}")" || {
          mv "$before" "$secrets"
          die "sops could not write wireguard/''${entry%%=*}: $secrets is as it was"
        }
      done
      rm "$before"
    }

    case $command in
      init)
        [ "$(state | jq -r '.publicKey // empty')" = "" ] || die "$file already has a server"
        private=$(wg genkey)
        new=$(state | jq --arg key "$(wg pubkey <<<"$private")" '.publicKey = $key')
        secret private_key "$private"
        write_secrets
        save <<<"$new"
        ;;

      add)
        name=''${1:-}
        [ -n "$name" ] || die "add takes the client's name"
        shift
        [[ $name =~ ^[A-Za-z0-9_.-]+$ ]] || die "a name takes letters, digits, _ . and - only: $name"
        endpoint=""
        public=""
        out=""
        while [ $# -gt 0 ]; do
          case $1 in
            --endpoint) endpoint=''${2:-} ;;
            --public-key) public=''${2:-} ;;
            -o) out=''${2:-} ;;
            *) die "unknown option $1" ;;
          esac
          shift 2 || die "$1 takes a value"
        done
        if [ -z "$endpoint" ]; then
          endpoint=$(sops decrypt --extract '["wireguard"]["endpoint"]' "$secrets" 2>/dev/null) ||
            die "say what clients connect to: --endpoint <public name>, or wireguard/endpoint in $secrets"
        fi
        serverKey=$(server_key)
        if has_client "$name"; then die "there is a client $name already"; fi

        address=$(state | jq -r --arg prefix "$prefix" \
          '[range(2; 255) | "\($prefix).\(.)"] - [.peers[].address] | first // empty')
        [ -n "$address" ] || die "${subnet} is full"

        private="<the client's private key>"
        if [ -z "$public" ]; then
          private=$(wg genkey)
          public=$(wg pubkey <<<"$private")
        fi
        psk=$(wg genpsk)
        conf="[Interface]
    PrivateKey = $private
    Address = $address/24${
      lib.optionalString (subnet6 != null) ", ${lib.removeSuffix "/64" subnet6}\${address##*.}/64"
    }
    DNS = ${lib.concatStringsSep ", " server.dns}

    [Peer]
    PublicKey = $serverKey
    PresharedKey = $psk
    Endpoint = $endpoint:${port}
    AllowedIPs = ${lib.concatStringsSep ", " server.allowedIPs}"

        new=$(state | jq --arg name "$name" --arg key "$public" --arg address "$address" \
          '.peers[$name] = { publicKey: $key, address: $address }')
        secret "psk/$name" "$psk"
        write_secrets
        save <<<"$new"

        if [ -n "$out" ]; then
          install -m 600 /dev/null "$out"
          echo "$conf" >"$out"
          echo "The client's configuration is in $out: delete it once the client has it." >&2
        else
          echo "$conf" >&2
          qrencode -t ansiutf8 <<<"$conf" >&2
        fi
        echo "$name is $address in $file." >&2
        ;;

      disable)
        existing_client "''${1:-}"
        state | jq --arg name "$1" '.peers[$name].enable = false' | save
        ;;

      enable)
        existing_client "''${1:-}"
        state | jq --arg name "$1" 'del(.peers[$name].enable)' | save
        ;;

      local-network)
        existing_client "''${1:-}"
        state | jq --arg name "$1" '.peers[$name].localNetwork = true' | save
        ;;

      internet-only)
        existing_client "''${1:-}"
        state | jq --arg name "$1" 'del(.peers[$name].localNetwork)' | save
        ;;

      remove)
        existing_client "''${1:-}"
        drop_secret "psk/$1"
        state | jq --arg name "$1" 'del(.peers[$name])' | save
        ;;

      rotate)
        out=""
        if [ "''${1:-}" = -o ]; then
          out=''${2:-}
          [ -n "$out" ] || die "-o takes a file"
          shift 2
        fi
        [ $# -eq 0 ] || die "unknown option $1"
        server_key >/dev/null
        names=$(state | jq -r '.peers | keys[]')
        [ -z "$out" ] || install -m 600 /dev/null "$out"

        private=$(wg genkey)
        serverKey=$(wg pubkey <<<"$private")
        secret private_key "$private"
        lines=""
        for name in $names; do
          psk=$(wg genpsk)
          secret "psk/$name" "$psk"
          printf -v lines '%s%s:\nPublicKey = %s\nPresharedKey = %s\n\n' "$lines" "$name" "$serverKey" "$psk"
        done
        write_secrets
        state | jq --arg key "$serverKey" '.publicKey = $key' | save

        echo "Commit $file and $secrets, and switch the server." >&2
        [ -n "$lines" ] || exit 0
        if [ -n "$out" ]; then
          printf %s "$lines" >"$out"
          echo "The lines each client has to change are in $out: delete it once the clients have them." >&2
        else
          printf %s "$lines" >&2
        fi
        echo "Once the server has switched, a client connects only with its two new lines in [Peer]." >&2
        ;;

      list)
        state | jq -r '.peers | to_entries | sort_by(.value.address | split(".") | map(tonumber))[]
          | [.key, .value.address, (if .value.enable == false then "disabled" else "" end),
            (if .value.localNetwork then "local network" else "" end), .value.publicKey] | @tsv' |
          column -t -s $'\t'
        ;;

      *)
        usage
        exit 1
        ;;
    esac
  '';
}
