# HTTPS support

If your application is running over HTTPS, you'll also need to configure the Tidewave App/CLI to expose its local server over HTTPS. There are three distinct ways to do so, depending on what tools you are using:

1. Configure the Tidewave App
2. Configure the Tidewave CLI
3. Configure Caddy or your proxy

Generally speaking, you want Tidewave and your application to run on the same host. Therefore, if you are running your server directly on localhost, you want to follow option 1 or 2. However, if you are using Caddy or a proxy to enable HTTPS, then you want them to also proxy to Tidewave itself.

## Configuring Tidewave App

If you are using the Tidewave App, click on the Tidewave icon (top-right on macOS and Linux, bottom-right on Windows) and choose "Settings". It will open up a configuration file where you can add:

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

Once you are done, remember to restart the application.

## Configuring Tidewave CLI

If you are using the Tidewave CLI, you can pass those values as options:

```shell
$ tidewave --https-port 9833 --https-cert-path ./cert.pem --https-key-path ./key.pem
```

## Configuring Caddy or a proxy

If you are using a proxy to enable HTTPS, we recommend using it to also proxy to Tidewave, so your application and Tidewave run in the same domain. The snippet below contains a sample Caddyfile that proxies `https://localhost:9833` to Tidewave running at `http://localhost:9832`.

```
https://localhost:9833 {
    # Uncommend if you want to use Caddy's own certificate
    # tls internal

    @hasOrigin header Origin https://localhost:9833
    reverse_proxy http://localhost:9832 {
        header_up @hasOrigin Origin "http://localhost:9832"
    }
}
```

If your app is running on `example.localhost`, you want to replace `localhost:9833` by `example.localhost:9833` in the snippet above. Also note that the Tidewave app checks the origin for security reasons, so you need to match and rewrite it accordingly.

## Troubleshooting

When using Tidewave Web, three components are invoked:

  * the Tidewave App/CLI
  * your web application
  * the browser

The browser talks to the Tidewave App/CLI and your web application. If you can load Tidewave in the browser (such as `https://localhost:9833`) and your web application, then it means their web servers are running and accessible over HTTPS.

However, the Tidewave App/CLI also needs to talk to your web application and it does so using the Operating System's trusted store. Therefore you need to install your web app certificate (the public .pem or .crt file) to your OS accordingly:

* macOS: Keychain Access
* Windows: Certificate Manager (certmgr.msc)
* Linux: Usually /etc/ssl/certs/ or using update-ca-certificates

And then restart the Tidewave App/CLI.

During Troubleshooting, you can use `curl` or `wget` to access your web application, as those tools also use the Operating System store. If they fail with certificate errors, Tidewave will likely experience the same issue.
