# Manages the clients of a host's my.wireguard server from a checkout.
{
  lib,
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  gnutar,
  gzip,
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
    gawk
    gnugrep
    gnutar
    gzip
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
    Usage: wireguard-${host} [--sops] <command>

      init                      a new server: makes its key
      import <wg0.conf|.tgz>    an existing server and its clients, from its
                                wg0.conf or a tar of /etc/wireguard (PiVPN's too)
      add <name> [--endpoint <public name>] [--public-key <key>] [-o <file>]
                                a new client; prints its configuration and QR code.
                                The endpoint defaults to wireguard/endpoint in
                                $secrets
      disable <name>            shuts a client out, and keeps its address and keys
      enable <name>
      remove <name>
      list

    Run it at the root of the repository. It writes $file;
    commit that file. The keys that are secret are printed for you to put in
    $secrets, or written there with --sops, which needs
    sops to be able to decrypt that file (SOPS_AGE_KEY).
    EOF
    }

    die() {
      echo "wireguard-${host}: $*" >&2
      exit 1
    }

    sops=
    if [ "''${1:-}" = --sops ]; then
      sops=1
      shift
      sops decrypt "$secrets" >/dev/null || die "sops cannot decrypt $secrets: is SOPS_AGE_KEY set?"
    fi
    command=''${1:-}
    [ $# -gt 0 ] && shift
    [ -z "$command" ] || [ -d "$(dirname "$file")" ] ||
      die "no $(dirname "$file") here: run it at the root of the repository"

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
      if [ -z "$sops" ]; then
        echo "Remove wireguard/$1 from $secrets." >&2
        return
      fi
      index=$(sops_index "$1")
      if sops decrypt --extract "$index" "$secrets" >/dev/null 2>&1; then
        sops unset "$secrets" "$index"
      fi
    }
    write_secrets() {
      [ ''${#pending[@]} -gt 0 ] || return 0
      local entry psk=""
      if [ -n "$sops" ]; then
        for entry in "''${pending[@]}"; do
          # printf is a shell builtin: the secret appears on no command line.
          printf %s "''${entry#*=}" | jq -Rs . |
            sops set --value-stdin "$secrets" "$(sops_index "''${entry%%=*}")"
        done
        return 0
      fi
      echo "Put these in $secrets (sops $secrets), then commit and switch:" >&2
      echo "wireguard:"
      for entry in "''${pending[@]}"; do
        case $entry in
          psk/*)
            [ -n "$psk" ] || echo "    psk:"
            psk=1
            entry=''${entry#psk/}
            echo "        ''${entry%%=*}: \"''${entry#*=}\""
            ;;
          *) echo "    ''${entry%%=*}: \"''${entry#*=}\"" ;;
        esac
      done
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

      import)
        [ $# -eq 1 ] || die "import takes the server's wg0.conf, or a tar of its /etc/wireguard"
        [ -f "$1" ] || die "no file $1"
        [ "$(state | jq '.peers | length')" = 0 ] || die "$file already has clients"
        case $1 in
          *.tgz | *.tar.gz | *.tar)
            member=$(tar tf "$1" | grep -E '(^|/)wg0\.conf$' | head -n 1) || die "$1 holds no wg0.conf"
            conf=$(tar xOf "$1" "$member")
            ;;
          *) conf=$(cat "$1") ;;
        esac

        # PiVPN names a peer in "### begin <name> ###" and comments out a
        # disabled one with "#[disabled] ".
        parsed=$(awk '
          function flush() {
            if (inpeer) printf "peer\037%s\037%s\037%s\037%s\037%s\n", name, enabled, pub, (psk == "" ? "-" : psk), ips
            inpeer = 0; pub = psk = ips = ""
          }
          {
            line = $0; disabled = 0
            sub(/\r$/, "", line)
            if (sub(/^#\[disabled\] ?/, "", line)) disabled = 1
          }
          line ~ /^### begin .* ###$/ { marker = line; sub(/^### begin /, "", marker); sub(/ ###$/, "", marker); next }
          line ~ /^### end / { next }
          line ~ /^#/ { comment = line; sub(/^#+ */, "", comment); next }
          line ~ /^\[Interface\]/ { flush(); section = "interface"; next }
          line ~ /^\[Peer\]/ {
            flush(); section = "peer"; inpeer = 1; count++
            name = marker != "" ? marker : (comment != "" ? comment : "peer" count)
            marker = comment = ""
            enabled = disabled ? "false" : "true"
            next
          }
          line ~ /=/ {
            key = tolower(line); sub(/[ \t]*=.*/, "", key)
            value = line; sub(/^[^=]*=[ \t]*/, "", value); sub(/[ \t]+$/, "", value)
            if (section == "interface") {
              if (key == "privatekey") private = value
              if (key == "address") address = value
              if (key == "listenport") port = value
            } else {
              if (key == "publickey") pub = value
              if (key == "presharedkey") psk = value
              if (key == "allowedips") ips = value
            }
            comment = ""
          }
          END { flush(); printf "interface\037%s\037%s\037%s\n", private, address, port }
        ' <<<"$conf")

        IFS=$'\037' read -r _ private address listen < <(grep '^interface' <<<"$parsed")
        [ -n "$private" ] || die "$1 has no PrivateKey"
        case ",''${address// /}," in
          *",$prefix.1/24,"*) ;;
          *) die "the server's address is $address, not $prefix.1/24: set my.wireguard.subnet to its network first" ;;
        esac
        [ "$listen" = ${port} ] ||
          echo "Note: the old server listens on ''${listen:-no fixed port}, my.wireguard.port is ${port}. Clients connect to the old one." >&2

        new=$(state | jq --arg key "$(wg pubkey <<<"$private")" '.publicKey = $key')
        secret private_key "$private"
        while IFS=$'\037' read -r _ name enabled pub psk ips; do
          name=$(tr -c 'A-Za-z0-9_.\n-' _ <<<"$name")
          [ -n "$pub" ] || die "client $name has no PublicKey"
          [ "$(jq --arg name "$name" '.peers | has($name)' <<<"$new")" = false ] || die "two clients are named $name"
          address=
          for ip in ''${ips//,/ }; do
            case $ip in
              "$prefix".*/32) address=''${ip%/32} ;;
              *) echo "Note: $name: $ip is not carried over, only its address in ${subnet}." >&2 ;;
            esac
          done
          [ -n "$address" ] || die "client $name has no address in ${subnet}: $ips"
          new=$(jq --arg name "$name" --arg key "$pub" --arg address "$address" --argjson enable "$enabled" \
            '.peers[$name] = { publicKey: $key, address: $address } + (if $enable then {} else { enable: false } end)' <<<"$new")
          [ "$psk" = - ] || secret "psk/$name" "$psk"
        done < <(grep '^peer' <<<"$parsed" || true)
        write_secrets
        save <<<"$new"
        echo "Imported $(jq '.peers | length' <<<"$new") clients into $file." >&2
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
            die "say what clients connect to: --endpoint <public name>, or wireguard/endpoint in $secrets (needs SOPS_AGE_KEY)"
        fi
        serverKey=$(state | jq -r '.publicKey // empty')
        [ -n "$serverKey" ] || die "$file has no server yet: run init, or import"
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

      remove)
        existing_client "''${1:-}"
        drop_secret "psk/$1"
        state | jq --arg name "$1" 'del(.peers[$name])' | save
        ;;

      list)
        state | jq -r '.peers | to_entries | sort_by(.value.address | split(".") | map(tonumber))[]
          | [.key, .value.address, (if .value.enable == false then "disabled" else "" end), .value.publicKey] | @tsv' |
          column -t -s $'\t'
        ;;

      *)
        usage
        exit 1
        ;;
    esac
  '';
}
