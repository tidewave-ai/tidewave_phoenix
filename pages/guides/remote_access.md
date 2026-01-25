# Remote access

You may want to run your web application on a separate machine than your current one. This guide explains how to do so.

First of all, Tidewave must always run on the same machine as your web application. After all, Tidewave needs access to your project and its files. This means that, when running Tidewave in a remote node, [you must use the Tidewave CLI](../installation.md#cli).

Additionally, for security reasons, the Tidewave CLI only allow access from `localhost` and `*.localhost` addresses and it disallows remote access by default. Therefore, if you want to run Tidewave in a separate address than `localhost` or allow remote access, you must configure it accordingly:

```
$ tidewave --allow-remote-access --allowed-origins https://example.com:9898
```

In the example above, `https://example.com:9898` is the exact address you will type in the browser, without any path or trailing slash. Note it is very important to have some sort of authentication on the remote machine, otherwise everyone can access your Tidewave instance (which gives them access to a coding agent with access to your code). However, if you are using Tidewave Teams, only members of your team would be able to access that instance.

> #### HTTPS advised {: .warning}
>
> We stronly advise using HTTPS addresses for remote access. We currently do not guarantee remote Tidewave instances work without HTTPS. See [HTTPS](https.md) guide for more information.

> #### Loopback address required {: .warning}
>
> Tidewave currently has a limitation that the remote machine must be able to access itself via its own address. Therefore, if you are using `https://example.com:9898` to access Tidewave on a remote machine, and your application is running on `https://example.com:4000`, then your machine must also be able to access `https://example.com:4000` within itself.