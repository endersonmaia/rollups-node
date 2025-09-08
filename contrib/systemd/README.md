# Initial setup

After you've installed cartesi-rollups-node and cartesi-machine-emulator, you should create a `cartesi` user that will be resposible for runnnig the services.

`adduser --system --group cartesi`

# Manage cartesi-rollups node services with systemd

Copy all `cartesi-rollups-*.service` files  to `/etc/systemd/system/`.

Run `systemctl daemon-reload`.

Enable each service with:


```
systemctl enable cartesi-rollups-env-reader.service
systemctl enable cartesi-rollups-advancer.service
systemctl enable cartesi-rollups-claimer.service
systemctl enable cartesi-inspect.service
systemctl enable cartesi-jsonrpc-api.service
```

Copy `sample.env` to `/etc/cartesi/config.env`.

Change its ownership and permission to `cartesi` user only.

```
chown cartesi:cartesi /etc/cartesi/config.env
chmod 0600 /etc/cartesi/config.env
```

Edit `/etc/cartesi/config.env` accordingly.

Then start each service:


```
systemctl start cartesi-rollups-env-reader.service
systemctl start cartesi-rollups-advancer.service
systemctl start cartesi-rollups-claimer.service
systemctl start cartesi-inspect.service
systemctl start cartesi-jsonrpc-api.service
```

You can follow logs for all services with:

```
journalctl -u cartesi-rollups-*.service -f
```

## Handling secrts with systemd-creds

Unless you're using AWS KMS to sign your transactions, you should consider using secrets for `CARTESI_AUTH_PRIVATE_KEY_FILE` or `CARTESI_AUTH_MNEMONIC_FILE`.

To handle secrets within systemd, you should use systemd-creds.

Run `systemd-creds setup`, if it's not ready yet.

> You should assess your system's config about support to use TPM module and filesystem encryption to secure data at rest.

Considering you're using mnemonic, create the secret to be loaded by the systemd service unit file.

```
echo -n "test test test test test test test test test test test junk" \
    | systemd-creds encrypt --name=cartesi_auth_mnemonic - /etc/cartesi/auth_mnemonic.enc
chown cartesi:cartesi /etc/cartesi/auth_mnemonic.enc
chmod 0600 /etc/cartesi/auth_mnemonic.enc
```

> Replace the `test test ... junk` with the acctual mnemonic.

Now edit `/etc/systemd/systeem/cartesi-rollups-claimer.service` like this:


```
[Service]
...
LoadCredentialEncrypted=cartesi_auth_mnemonic:/etc/cartesi/auth_mnemonic.enc
Environment="CARTESI_AUTH_MNEMONIC_FILE=%d/cartesi_auth_mnemonic"
```

Something similar could be done if you use a Private Key format instead.

The same strategy could be done for other configuration you consider to be sensible:

- `CARTESI_BLOCKCHAIN_HTTP_ENDPOINT`
- `CARTESI_BLOCKCHAIN_WS_ENDPOINT`
- `CARTESI_DATABASE_CONNECTION`

# TBD - database init

```
# su - postgres
$ createdb rollups
$ psql -s rollups
# create user rollups password 'rollups';
# GRANT ALL PRIVILEGES ON DATABASE rollups TO rollups;
# GRANT ALL ON SCHEMA public TO rollups;
```
