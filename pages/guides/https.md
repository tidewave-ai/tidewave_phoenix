# HTTPS support

If you want to run your application over HTTPS, you'll also need to expose Tidewave over HTTPS. There are two distinct ways to do so, depending on what tools you are using:

1. Configure Caddy or a proxy: this implies you are using a third party tool to expose your application over HTTPS. You can use the same tool to expose Tidewave too. This is often the simplest approach

2. Configure your application and Tidewave: you are directly configuring your framework or build tool to serve over HTTPS, and you need to match Tidewave accordingly

Once setup, please read the Security Considerations section at the end for additional configuration.

## Configuring Caddy or a proxy

If you are using a proxy to enable HTTPS, we recommend using it to also proxy to Tidewave, so your application and Tidewave run in the same domain. The snippet below contains a sample Caddyfile that proxies `https://localhost:9833` to Tidewave running at `http://localhost:9832`.

```caddyfile
https://localhost:9833 {
    # Uncommend if you want to use Caddy's own certificate
    # tls internal

    reverse_proxy http://localhost:9832 {
        header_up Origin "https://localhost:9833" "http://localhost:9832"
    }
}
```

If your app is running on `example.localhost`, you want to replace `localhost:9833` by `example.localhost:9833` in the snippet above. Also note that the Tidewave app checks the origin for security reasons, so we match and rewrite it accordingly.

## Configuring your application and Tidewave

If you are directly configuring your web framework or build tool to run over HTTPS, you must also configure Tidewave. The steps will differ if you are using Tidewave's Desktop App or the Tidewave CLI. 

### Enabling HTTPS in the Tidewave App

If you are using the Tidewave App, click on the Tidewave icon (top-right on macOS and Linux, bottom-right on Windows) and choose "Settings". It will open up a configuration file where you can add:

```toml
https_port = 9833
https_cert_path = "/path/to/cert.pem"
https_key_path = "/path/to/key.pem"
```

You can use your own certificates or generate one using:

```shell
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

Once you are done, remember to restart the application.

### Enabling HTTPS in the Tidewave CLI

If you are using the Tidewave CLI, you can pass those values as options:

```shell
$ tidewave --https-port 9833 --https-cert-path ./cert.pem --https-key-path ./key.pem
```

## Security considerations

For security reasons, the Tidewave App and Tidewave CLI only allow access from `localhost` and `*.localhost` addresses. Furthermore, Tidewave does not allow remote access by default. Therefore, if you want to run Tidewave in a separate address than `localhost` or allow remote access, you must configure it accordingly:

### Allowing origins and remote access in the Tidewave App

Click on the Tidewave icon (top-right on macOS and Linux, bottom-right on Windows) and choose "Settings". It will open up a configuration file where you can add:

```toml
# Allow access from other machines, only enable it in safe networks
allow_remote_access = true
# Use the addresses you will insert in the browser to actually open up Tidewave 
allowed_origins = ["https://example.com:9898"]
```

Once you are done, remember to restart the application.

### Allowing origins and remote access in the Tidewave CLI

If you are using the Tidewave CLI, you can pass those values as options:

```
$ tidewave --allow-remote-access --allowed-origins https://example.com:9898
```

## Troubleshooting

### Invalid certificate

Tidewave Web is made of three components:

  * the Tidewave App/CLI
  * your web application
  * the browser

The browser talks to the Tidewave App/CLI and your web application. If you can load Tidewave in the browser (such as `https://localhost:9833`) and your web application directly (say `https://localhost:4000`), then it means their web servers are running and accessible over HTTPS.

However, when loading your web application inside Tidewave Web, the Tidewave App/CLI also needs to talk to your web application and it does so using the Operating System's trusted store. Therefore you need to install your web app certificate (the public .pem or .crt file) to your OS accordingly:

* macOS: Keychain Access
* Windows: Certificate Manager (certmgr.msc)
* Linux: Usually /etc/ssl/certs/ or using update-ca-certificates

After installed, make sure the certificates are marked as trusted. And then restart the Tidewave App/CLI.

During Troubleshooting, you can use `curl` or `wget` to access your web application, as those tools also use the Operating System store. If they fail with certificate errors, Tidewave will likely experience the same issue.

### Invalid name in certificate

When generating a certificate, you must specify the name of the certificate. You must do so in two places, by passing the Common Name (CN) field to `subj`, and by passing `subjectAltName`, as shown below:

```shell
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

Certificates that specify only the Common Name (CN) are not considered valid by many HTTP clients. If your certificate does not have a `subjectAltName`, it won't work with Tidewave.
