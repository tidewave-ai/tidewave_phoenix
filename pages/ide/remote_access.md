# Remote access

You can run the Tidewave IDE remotely and allow users to remotely access it. This guide explains how to do so.

First of all, Tidewave IDE must always run on the same machine as your web application. After all, Tidewave IDE needs access to your project and its files. This means that, when running Tidewave IDE in a remote node, [you must use the Tidewave IDE CLI](installation.md#cli).

Additionally, for security reasons, the Tidewave IDE CLI only allows access from `localhost` and `*.localhost` addresses and it disallows remote access by default. Therefore, if you want to run Tidewave IDE in a separate address than `localhost` or allow remote access, you must configure it accordingly:

```
$ tidewave --allow-remote-access --allowed-origins https://example.com:9898
```

In the example above, `https://example.com:9898` is the exact address you will type in the browser, without any path or trailing slash. Note it is very important to have some sort of authentication or gate access to the remote machine, otherwise everyone can access your Tidewave IDE App/CLI directly.

Finally, you must configure your web application itself to allow remote access. Most web frameworks bind to localhost by default and, similarly to Tidewave IDE, do not allow remote access. Consult your framework documentation for more information.

> #### HTTPS advised {: .warning}
>
> We strongly advise using HTTPS addresses for remote access. We currently do not guarantee remote Tidewave IDE instances work without HTTPS. See [HTTPS](https.md) guide for more information.

> #### Containers configuration {: .info}
>
> If you are deploying remotely using containers, see our [Containers](containers.md) guide.
