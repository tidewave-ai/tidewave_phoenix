# Remote access

You may want to run your web application on a separate machine than your current one. This guide explains how to do so.

First of all, Tidewave must always run on the same machine as your web application. After all, Tidewave needs access to your project and its files. This means that, when running Tidewave in a remote node, [you must use the Tidewave CLI](../installation.md#cli).

Additionally, for security reasons, the Tidewave CLI only allow access from `localhost` and `*.localhost` addresses and it disallows remote access by default. Therefore, if you want to run Tidewave in a separate address than `localhost` or allow remote access, you must configure it accordingly:

```
$ tidewave --allow-remote-access --allowed-origins https://example.com:9898
```

In the example above, `https://example.com:9898` is the exact address you will type in the browser, without any path or trailing slash. Note it is very important to have some sort of authentication or gate access to the remote machine, otherwise everyone can access your Tidewave App/CLI directly.

Finally, you must configure your web application itself to allow remote access. Most web frameworks bind to localhost by default and, similarly to Tidewave, do not allow remote access. Consult your framework documentation for more information.

> #### HTTPS advised {: .warning}
>
> We strongly advise using HTTPS addresses for remote access. We currently do not guarantee remote Tidewave instances work without HTTPS. See [HTTPS](https.md) guide for more information.
