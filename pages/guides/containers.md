# Containers

To isolate the agent environment from your local machine, you can use containers.
Because Tidewave runs inside your application, running it in a container automatically isolates Tidewave as well.

One popular solution for this is [Visual Studio Code's dev containers](https://code.visualstudio.com/docs/devcontainers/containers). Tidewave works out of the box when using dev containers.
In the section below, we'll be looking at a minimal, dev container like, setup.

## Build your own dev container

Note: this guide assumes that if you are using Windows, you're also using WSL.
Note: this guide assumes some familiarity with using Docker.

When you use another editor than VSCode, you can build a similar experience with Tidewave running inside your development container, but your editor on your local machine.

First, because you usally have some external systems you depend on, for example a Postgres database, let's define a `docker-compose.dev.yml` file inside your project:

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

Next, create a new `Dockerfile.dev` file, which will contain all the tools you need to run your dev server. For this example, we assume a Phoenix project.
For Ruby, you would choose a different base image.

```dockerfile
FROM hexpm/elixir:1.18.4-erlang-27.3.4-ubuntu-noble-20250529

RUN mix local.hex --force
RUN mix local.rebar --force

RUN apt update && apt -y install git bash inotify-tools socat
RUN <<EOF cat >> /run.sh
#!/bin/sh

socat TCP-LISTEN:4001,fork TCP:localhost:4000 > /dev/null 2>&1 &
socat TCP-LISTEN:localhost:5432,fork TCP:db:5432 > /dev/null 2>&1 &

bash
EOF
RUN chmod +x run.sh
```

We install a couple of tools, notabily `git` for fetching git dependencies inside of the container as well as `socat`. `socat` is needed to forward traffic to our development server,
which by default only listens on localhost. When using Docker's built-in port forwarding this would not work, because Docker accesses the container through a different IP.
You could configure your project to listen on all addresses in development, but this could lead to security issues if you sometimes also run your project outside of Docker.
Furthermore, the default Phoenix project assumes Postgres to listen on localhost, therefore we also use socat to forward any traffic from port 5432 to the `db` container.

To comfortably start the container with all network settings, let's also create a `dev.sh` script:

```bash
#!/bin/sh
docker compose -f docker-compose.dev.yml up -d
docker build -f Dockerfile.dev -t tidewave-devcontainer .
docker run --rm -w $(pwd) \
  -v $(pwd):$(pwd) \
  -p 127.0.0.1:4000:4001 \
  -it tidewave-devcontainer /run.sh
```

This script starts the compose project and builds our custom container image. Then, it starts an ephemeral dev container, mapping the current working directory into it
and forwarding 127.0.0.1:4000 to socat. This allows you to access your Phoenix dev server from your browser on port 4000, as usual.
We only bind to `127.0.0.1` for security purposes. Don't use `-p 4000:4001`, otherwise anyone on your local network could access the Tidewave MCP server.

### Downsides

Compared to VSCode's dev containers, this setup still runs your editor outside of the container. So while any Tidewave tools will be constrained to the container,
any tools your editor might bring to edit files and run terminal commands are still potentially dangerous if you let the agent use those without supervision.
