# HTTPS support

If your application is running over HTTPS, you'll also need to configure the Tidewave application to expose its local server over HTTPS.

To do so, click on the Tidewave icon (top-right on macOS and Linux, bottom-right on Windows) and choose "Settings". It will open up a configuration file where you can add:

```toml
https_port = 9833
https_cert_path = "/path/to/cert.pem"
https_key_path = "/path/to/key.pem"
```

You can use your own certificates or generate one using:

```
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

If you are using the Tidewave CLI, you can also pass those values as options:

```shell
$ tidewave --https-port 9833 --https-cert-path ./cert.pem --https-key-path ./key.pem
```
