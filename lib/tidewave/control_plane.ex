defmodule Tidewave.ControlPlane do
  @moduledoc false

  # Helpers and the static control page for Tidewave's browser control plane.
  #
  # The control plane lets a connected agent open browser sessions (iframes) and
  # run JavaScript against them via the `browser_session`/`browser_eval` MCP
  # tools. It is opt-in:
  #
  #     config :tidewave, enable_control_plane: true
  #
  # It also requires the socket to be mounted in the host endpoint:
  #
  #     socket "/tidewave/socket", Tidewave.Socket
  #
  # The human opens `/tidewave/control`, which connects over
  # `Tidewave.BrowserChannel` and hosts the sessions agents target.

  # ~S so JavaScript escapes (\n) and any #{} survive verbatim into the source.
  @page_html ~S"""
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <meta name="robots" content="noindex" />
      <title>Tidewave Control</title>
      <script src="/tidewave/phoenix.js"></script>
      <style>
        body { font-family: system-ui, sans-serif; margin: 0; padding: 1rem; }
        h1 { font-size: 1.1rem; margin: 0 0 .5rem; }
        #status { color: #555; margin: 0 0 1rem; font-size: .9rem; }
        .session { border: 1px solid #ddd; border-radius: 6px; margin-bottom: 1rem; overflow: hidden; }
        .session h2 { font-size: .85rem; margin: 0; padding: .4rem .6rem; background: #f5f5f5; }
        .session iframe { display: block; width: 100%; height: 70vh; border: 0; }
      </style>
    </head>
    <body>
      <h1>Tidewave Control</h1>
      <p id="status">Connecting…</p>
      <div id="sessions"></div>
      <script>
        (() => {
          const { Socket } = window.Phoenix;
          const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
          const sessions = {};
          const statusEl = document.getElementById("status");
          const sessionsEl = document.getElementById("sessions");

          const socket = new Socket("/tidewave/socket");
          socket.connect();
          const channel = socket.channel("tidewave:browser", {});

          channel
            .join()
            .receive("ok", () => {
              statusEl.textContent = "Connected. Waiting for sessions…";
            })
            .receive("error", (resp) => {
              statusEl.textContent = "Unable to join: " + JSON.stringify(resp);
            });

          channel.on("open_session", (payload) => {
            openSession(payload.ref, payload.name, payload.path);
          });

          channel.on("browser_eval", (payload) => {
            runEval(payload.session, payload.input).then((result) => {
              channel.push("browser_eval_reply", { ref: payload.ref, result });
            });
          });

          function openSession(ref, name, path) {
            try {
              const wrapper = document.createElement("section");
              wrapper.className = "session";

              const title = document.createElement("h2");
              title.textContent = name + " — " + path;

              const iframe = document.createElement("iframe");
              iframe.title = name;

              wrapper.appendChild(title);
              wrapper.appendChild(iframe);
              sessionsEl.appendChild(wrapper);
              sessions[name] = iframe;

              let settled = false;
              const onLoad = () => {
                if (settled) return;
                settled = true;
                iframe.removeEventListener("load", onLoad);
                channel.push("session_opened", { ref });
              };
              iframe.addEventListener("load", onLoad);
              iframe.src = path;
            } catch (e) {
              channel.push("session_opened", { ref, error: String(e) });
            }
          }

          async function runEval(name, input) {
            const iframe = sessions[name];
            if (!iframe) {
              return { text: "The browser session is no longer available.", isError: true };
            }

            const logs = [];
            const console = makeConsole(logs);
            const browser = makeBrowser(iframe);

            try {
              const fn = new AsyncFunction("browser", "console", input.code);
              await fn(browser, console);
              return { text: logs.join("\n"), isError: false };
            } catch (e) {
              const message = e && e.stack ? e.stack : String(e);
              const text = logs.length ? logs.join("\n") + "\n\n" + message : message;
              return { text, isError: true };
            }
          }

          function makeConsole(logs) {
            const record = (...args) => logs.push(args.map(format).join(" "));
            return { log: record, info: record, warn: record, error: record, debug: record };
          }

          function format(value) {
            if (typeof value === "string") return value;
            try {
              return JSON.stringify(value);
            } catch (_e) {
              return String(value);
            }
          }

          // Minimal `browser` API. Code given to browser_eval MUST use it.
          function makeBrowser(iframe) {
            return {
              // Navigate to a path (or reload) and resolve once loaded.
              reload(path) {
                return new Promise((resolve) => {
                  const onLoad = () => {
                    iframe.removeEventListener("load", onLoad);
                    resolve();
                  };
                  iframe.addEventListener("load", onLoad);
                  if (path != null) {
                    iframe.src = path;
                  } else {
                    iframe.contentWindow.location.reload();
                  }
                });
              },
              // Wait for the given number of milliseconds.
              wait(ms) {
                return new Promise((resolve) => setTimeout(resolve, ms));
              },
              // Run a function inside the page (iframe) realm. It MUST NOT
              // reference outside variables; pass data as the second argument.
              async eval(fun, arg) {
                const realmFn = iframe.contentWindow.eval("(" + fun.toString() + ")");
                return await realmFn(arg);
              },
            };
          }
        })();
      </script>
    </body>
  </html>
  """

  @doc """
  Whether the browser control plane is enabled.
  """
  def enabled? do
    Application.get_env(:tidewave, :enable_control_plane, false)
  end

  @doc """
  The static HTML (with inlined JavaScript) for `/tidewave/control`.
  """
  def page_html do
    @page_html
  end
end
