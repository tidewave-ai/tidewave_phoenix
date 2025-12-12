# HTTPS support

If your application is running over HTTPS, you'll also need to configure the Tidewave App/CLI to expose its local server over HTTPS.

## Configuring Tidewave App

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

Once you are done, remember to restart the application.

## Configuring Tidewave CLI

If you are using the Tidewave CLI, you can pass those values as options:

```shell
$ tidewave --https-port 9833 --https-cert-path ./cert.pem --https-key-path ./key.pem
```

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
