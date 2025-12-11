# Containers

To isolate the agent environment from your local machine, you can use containers.
Because Tidewave runs within your web application, running your app in a container
automatically isolates Tidewave as well, this makes Tidewave simpler to containerize
than other agents.

> #### Tidewave CLI
>
> In order to use Tidewave Web with [ACP support](https://agentclientprotocol.com/overview/introduction), you'll
> also need to add the [Tidewave CLI](https://github.com/tidewave-ai/tidewave_app) to your container image and
> start it alongside your web application. You cannot use the Tidewave Desktop app from outside the container
> to connect to Tidewave inside the container.

One popular solution for this is [Visual Studio Code's dev containers](https://code.visualstudio.com/docs/devcontainers/containers).
Tidewave works out of the box when using devcontainers. Just download the latest `tidewave` CLI binary with curl or wget in a
Terminal inside your container:

```bash
$ curl -sL -o tidewave https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-aarch64-unknown-linux-musl
$ chmod +x tidewave
$ ./tidewave
2025-11-03T16:27:00.232551Z  INFO tidewave_core::server: HTTP server bound to 127.0.0.1:9832
```

In the section below, we'll be looking at a minimal, devcontainer-like, setup.

## Build your own dev container

> #### Windows users {: .info}
>
> This guide assumes that if you are using Windows, you're also using WSL.

> #### Docker familiarity {: .info}
>
> This guide assumes some familiarity with using Docker.

When you use another editor than VSCode, you can build a similar experience to
devcontainer, with your web app and Tidewave running inside Docker, but your
editor on your local machine.

First, because you usally have some external systems you depend on, for example
a Postgres database, let's define a `docker-compose.dev.yml` file inside your
project:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: my_app_dev
    volumes:
      - ./db:/var/lib/postgresql/data
    networks:
      - my_app

networks:
  my_app:
    name: my_app
```

Next, create a new `Dockerfile.dev` file, which will contain all
the tools you need to run your dev server. We have some examples
based on your web framework below:

<!-- tabs-open -->

### Ruby on Rails


```dockerfile
FROM ruby:3.2

RUN apt update && apt -y install curl git bash inotify-tools socat
RUN curl -sL -o tidewave https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-$(uname -m)-unknown-linux-musl && \
    chmod +x tidewave && \
    mv tidewave /usr/local/bin/tidewave
RUN <<EOF cat >> /run.sh
#!/bin/sh

socat TCP-LISTEN:3001,fork TCP:localhost:3000 > /dev/null 2>&1 &
socat TCP-LISTEN:5432,fork,bind=127.0.0.1 TCP:db:5432 > /dev/null 2>&1 &
socat TCP-LISTEN:9001,fork TCP:localhost:9000 > /dev/null 2>&1 &
tidewave -p 9000 > /dev/null 2>&1 &

bash
EOF
RUN chmod +x run.sh
```

### Phoenix

```dockerfile
FROM hexpm/elixir:1.18.4-erlang-27.3.4-ubuntu-noble-20250529

RUN mix local.hex --force
RUN mix local.rebar --force

RUN apt update && apt -y install curl git bash inotify-tools socat
RUN curl -sL -o tidewave https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-$(uname -m)-unknown-linux-musl && \
    chmod +x tidewave && \
    mv tidewave /usr/local/bin/tidewave
RUN <<EOF cat >> /run.sh
#!/bin/sh

socat TCP-LISTEN:4001,fork TCP:localhost:4000 > /dev/null 2>&1 &
socat TCP-LISTEN:5432,fork,bind=127.0.0.1 TCP:db:5432 > /dev/null 2>&1 &
socat TCP-LISTEN:9001,fork TCP:localhost:9000 > /dev/null 2>&1 &
tidewave -p 9000 > /dev/null 2>&1 &

bash
EOF
RUN chmod +x run.sh
```

<!-- tabs-close -->

We install a couple of tools, notably `git` for fetching git dependencies inside
of the container as well as `socat`. `socat` is needed to forward traffic to our
development server, which by default only listens on localhost. When using Docker's
built-in port forwarding this would not work, because Docker accesses the container
through a different IP.

You could configure your project to listen on all addresses in development, but this
could lead to security issues if you sometimes also run your project outside of Docker.
If you are using databases or other resources, such as Redis, you must also forward them.
The examples above assume there is a PostgreSQL instance running on port 5421 and
therefore we also use socat to forward any traffic from port 5432 to the `db` container.

To comfortably start the container with all network settings, let's also create a `dev.sh` script:

```bash
#!/bin/sh
docker compose -f docker-compose.dev.yml up -d
docker build -f Dockerfile.dev -t tidewave-devcontainer .
docker run --rm -w $(pwd) \
  -v $(pwd):$(pwd) \
  --network my_app \
  -p 127.0.0.1:3000:3001 \
  -p 127.0.0.1:9000:9001 \
  -it tidewave-devcontainer /run.sh
```

This script starts the compose project and builds our custom container image.
Then, it starts an ephemeral dev container, mapping the current working directory.

Also pay close attention to the `-p` parameter above:

* This configuration allows you to access your web app in your browser
  using `localhost` as usual.

* We used ports 3000:3001 but you need to adapt them to your web framework
  (such as 4000:4001 for Phoenix).

* We forward the ports for the Tidewave CLI as well, such that you can access it
  at `http://localhost:9000`.

* We only bind to `127.0.0.1` for security purposes. Don't use `-p 3000:3001`,
  otherwise anyone on your local network can access your web app and Tidewave.

Compared to VSCode's devcontainers, this setup still runs your editor outside
of the container. So while Tidewave will be constrained to the container,
any tools your editor might bring to edit files and run terminal commands are
still potentially dangerous if you let the agent use those without supervision.

If you prefer to not run your web app on `localhost`, check the installation
steps for each framework on GitHub to learn how to customize them.