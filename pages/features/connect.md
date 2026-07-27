# Browser connect

Tidewave Connect allows your coding agent to connect to your browser and control your web application:

<img src="assets/connect.png" alt="Tidewave Connect">

It is similar to tools like [Playwright](https://playwright.dev) or the browser in your editor, with a few notable differences:

* **Uses your browser**: Tidewave uses your existing browser and sessions, making it much easier for the agent to see and debug the same page you are working with

* **Error handling**: Because Tidewave understands your framework, it automatically recognizes error pages and feeds stacktraces, logs, framework metadata to the agent

* **Vision mode**: [Tidewave's vision mode](vision_mode.md) includes the ability to record videos with captions, narration, and other bells and whistles for proof of work

To enable Tidewave Connect, simply install the [Tidewave MCP](../mcp/mcp.md) in your coding agent of choice and ask it to use the `browser_eval` tool. You will need to also open up your web app at `/tidewave` in your browser of choice.

## Viewport

Tidewave Connect offers the ability to customize the viewport, allowing developers to simulate different devices. To use it, click on the display icon on the top right:

<img src="assets/viewport.png" alt="Tidewave Viewport">

Once enabled, you can either select one of the available presets or type custom dimensions.

The viewport is also available to coding agents. This means coding agents can automatically test and verify breakpoints. For example, you can ask how your app renders on mobile and the agent will match what the code says with how the app behaves in practice:

<iframe width="640" height="360" src="https://www.youtube.com/embed/Nsb-9BNpfuc?si=AfMcuMcVv8fkSU2R" title="Tidewave Viewport" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
