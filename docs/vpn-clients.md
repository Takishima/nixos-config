# How to manage the VPN's clients

This guide shows you how to add, list, shut out and remove the clients of a VPN
server. The examples are for `rpizh`; `rpius` has the same command under its
name.

`wireguard-rpizh` manages the clients from a checkout of this repository, on any
machine. Run it at the root of the checkout:

```sh
nix run .#wireguard-rpizh -- add phone      # a new client
nix run .#wireguard-rpizh -- list
nix run .#wireguard-rpizh -- disable phone  # shut out, until `enable phone`
nix run .#wireguard-rpizh -- remove phone
```

Each command changes `hosts/rpizh/wireguard.json`. With `--sops` it also changes
the preshared key in `secrets/rpizh.yaml`, and needs `SOPS_AGE_KEY`, set as in
[step 2 of provisioning](raspberry-pi.md#2-secrets). Without `--sops` it prints
what to put there.

Commit both files. The server has the client after its next switch: see
[Updates](raspberry-pi.md#updates).

On the server, as root, `wg-peers` shows which clients are connected: it is
`wg show wg0` with each client's name before its key.

## A new client

`add` gives the client the next free address, and prints its configuration and
the QR code for the phone app.

- Nothing else keeps the client's private key. Scan the code then, or have the
  configuration written with `-o phone.conf`.
- The endpoint in the configuration is `wireguard/endpoint` of the sops file,
  read with `SOPS_AGE_KEY`. `--endpoint <public name>` gives it instead.
- A client that made its own key pair hands in the public key,
  `--public-key <key>`, and keeps the other.

## Where the VPN's settings are

| What | Where |
| --- | --- |
| Port, subnet | `my.wireguard` in `hosts/rpizh/default.nix` |
| IPv6 for the clients, and whether they reach one another | `my.wireguard.subnet6`, `my.wireguard.clientToClient` |
| DNS and routes written into a new client's configuration | `my.wireguard.dns`, `my.wireguard.allowedIPs` |
| The clients: name, public key, address, whether one is shut out | `hosts/rpizh/wireguard.json` |
| The server's private key, the clients' preshared keys | `wireguard/private_key`, `wireguard/psk/<client>` in the sops file |

`add` writes both addresses of a client when `my.wireguard.subnet6` is set. An
older client gets IPv6 once its `Address` line has the second one:
`Address = 10.6.0.7/24, <subnet6>::7/64`.
