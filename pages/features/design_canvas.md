# Design canvas

The design canvas allows you to explore and refine interface ideas with your coding agent on a visual canvas. You can compare multiple directions side by side, explore navigation flows, and even build wireframes.

<a href="assets/coffee-hero-canvas.html" target="_blank">
<img src="assets/design-canvas.png" alt="Design canvas example" />
</a>

The canvas is a standalone HTML file, written to disk, which you can check-in into version control or share with your colleagues on Slack. [Here is a sample design canvas for a coffee shop website](assets/coffee-hero-canvas.html){:target="_blank"}.

You can ask your coding agent to create a design canvas at any moment, which is then done by invoking the `create_design_canvas` tool from Tidewave's MCP. The design canvas comes with both inspector and zoom features. You can also use drag and drop to navigate the canvas, or hold `Cmd`/`Ctrl` and use your scroll wheel to zoom in and out.

> #### Design canvas vs UI variants {: .info}
>
> Tidewave also has a feature called [UI variants](ui_variants.md). Use UI variants when you want to try out different variations of a component within an existing page. Use the design canvas when you need to step back and explore different versions at a macro level, visualize navigation across screens, or when you need to share the artifact with colleagues.

> #### Tidewave IDE {: .info}
>
> Design canvas is available by default within the Tidewave IDE. The Tidewave IDE can also render the canvas inline and reload it live, as the coding agent changes it on disk.