# Install the Tidewave IDE

Tidewave IDE is an agentic dev environment for Phoenix and Rails. It is an IDE that runs in the browser, allowing your coding agent to seamlessly interact with your web application. [See our Tidewave IDE page](https://tidewave.ai/ide) for more information.

Tidewave IDE is an additional product which requires installing a desktop app (or additional CLI tools).

> #### Tidewave vs Tidewave IDE {: .info}
>
> This page is about installing the Tidewave IDE, which is an agentic IDE that runs in your browser. If you are looking for the Tidewave Toolbar, [follow the steps to install the Tidewave package instead](https://tidewave.ai/toolbar#download).

## Installing the app

To get started with Tidewave IDE, download our desktop app:

* For macOS: [Apple Silicon](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-app-aarch64.dmg), [Intel](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-app-x64.dmg)
* For Linux: [AppImage (x86_64)](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-app-amd64.AppImage), [AppImage (ARM64)](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-app-aarch64.AppImage)
* For Windows: [Windows](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-app-x64.exe) (the desktop app is also recommended when using WSL)

After installation, an icon should appear in your menu bar (top-right on macOS and Linux, bottom-right on Windows).

We also offer a [CLI](#cli) if you are running your application remotely, inside containers, or other cases where the desktop application is not an option. If you are using Docker, read [our containers guide](containers.md).

## Running Tidewave IDE

After installation, you can run the Tidewave IDE application. By default, it will run a service on [`http://localhost:9832`](http://localhost:9832), which you can access from your favorite browser. Once you do, you will be greeted with this screen:

![Welcome to Tidewave IDE](assets/tidewave-app.png)

Then you can put the address of your web application and Tidewave IDE will connect to it. If your web application was not yet configured with Tidewave IDE, you will be prompted to do so, using the links below:

* [Tidewave IDE for Phoenix](https://github.com/tidewave-ai/tidewave_phoenix)
* [Tidewave IDE for Ruby on Rails](https://github.com/tidewave-ai/tidewave_rails)
* [Tidewave IDE for TanStack Start](https://github.com/tidewave-ai/tidewave_js)
* [Tidewave IDE for Vite](https://github.com/tidewave-ai/tidewave_js)

The Tidewave IDE app will remain running on your menu bar (top right on macOS/Linux, bottom right on Windows), you can click it to open up, configure, and update Tidewave IDE.

Remember Tidewave IDE must always run on the same machine as your web server is running. If your web server is running on a separate machine, you will want to use our CLI.

## CLI

For running Tidewave IDE inside containers and other advanced uses, a CLI is also available:

* For macOS: [Apple Silicon](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-aarch64-apple-darwin), [Intel](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-x86_64-apple-darwin)
* For Windows: [Windows](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-x86_64-pc-windows-msvc.exe)
* For Linux: [aarch64-gnu](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-aarch64-unknown-linux-gnu), [aarch64-musl](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-aarch64-unknown-linux-musl), [x86_64-gnu](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-x86_64-unknown-linux-gnu), [x86_64-musl](https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-x86_64-unknown-linux-musl)

Once the CLI is installed, run it with `./tidewave`. Run `./tidewave --help` for a list of all options. 

For security reasons, the CLI only allows access from the same machine it is running on by default. Furthermore, it enforces that the CLI is being accessed from `localhost` or `127.0.0.1`. If you want to run the CLI on a custom server, you must pass `--allow-remote-access` and `--allowed-origins=https://HOSTNAME:PORT` respectively to change our defaults. You can also [enable HTTPS certificates](https.md) both for the App and the CLI.

Both [our App and CLI are open source](https://github.com/tidewave-ai/tidewave_app).
