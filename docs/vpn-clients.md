# How to manage the VPN's clients

This guide shows you how to add, list, shut out and remove the clients of a VPN
server, and how to give the server new keys. The examples are for `rpizh`;
`rpius` has the same command under its name.

`wireguard-rpizh` manages the clients from a checkout of this repository, on any
machine. Set `SOPS_AGE_KEY` first, as in
[step 2 of provisioning](raspberry-pi.md#2-secrets): `--sops` and `add` read
`secrets/rpizh.yaml` with it. Then run the command at the root of the checkout:

```sh
nix run .#wireguard-rpizh -- --sops add phone     # a new client
nix run .#wireguard-rpizh -- list
nix run .#wireguard-rpizh -- disable phone        # shut out, until `enable phone`
nix run .#wireguard-rpizh -- --sops remove phone
```

`add`, `disable`, `enable`, `remove` and `rotate` change
`hosts/rpizh/wireguard.json`. With `--sops`, `add`, `remove` and `rotate` also
change the keys in `secrets/rpizh.yaml`. Without it, they print what to change
there.

Commit what changed to `main`. The server has the change after its next
upgrade. To shut a client out at once, switch the server by hand: see
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

## New keys after a leak

If the server's WireGuard key may have leaked, as with a `wg0.conf` left on a
machine, `rotate` replaces it and every client's preshared key. The clients
keep their names, addresses and key pairs.

If the SD card itself is lost, `rotate` is not enough. The card holds the Pi's
SSH host key, which decrypts everything in `secrets/rpizh.yaml`, also what
`rotate` writes later. First replace the host key: make a new one in 1Password,
put its age recipient in `.sops.yaml`, run `sops updatekeys secrets/rpizh.yaml`
and set `SOPS_AGE_KEY` from the new key. Then change every other secret in the
file, run `rotate`, and [write a new card](raspberry-pi.md#5-write-the-card).

1. Make the new keys, in a file outside the checkout:

   ```sh
   nix run .#wireguard-rpizh -- --sops rotate -o ~/rotated.txt
   ```

2. Commit `hosts/rpizh/wireguard.json` and `secrets/rpizh.yaml` to `main`.
3. Switch the server: see [Updates](raspberry-pi.md#updates). From then on, no
   client connects with its old configuration.
4. In each client's configuration, set `PublicKey` and `PresharedKey` in the
   `[Peer]` section to its two lines from `~/rotated.txt`. Add the
   `PresharedKey` line if the client has none.
5. Delete `~/rotated.txt`.

## Where the VPN's settings are

| What | Where |
| --- | --- |
| Port, subnet | `my.wireguard` in `hosts/rpizh/default.nix` |
| IPv6 for the clients | `my.wireguard.subnet6` |
| DNS and routes written into a new client's configuration | `my.wireguard.dns`, `my.wireguard.allowedIPs` |
| The clients: name, public key, address, whether one is shut out | `hosts/rpizh/wireguard.json` |
| The server's private key, the clients' preshared keys | `wireguard/private_key`, `wireguard/psk/<client>` in the sops file |

`add` writes both addresses of a client when `my.wireguard.subnet6` is set. An
older client gets IPv6 once its `Address` line has the second one:
`Address = 10.6.0.7/24, <subnet6>::7/64`.
