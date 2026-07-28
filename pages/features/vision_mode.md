# Vision mode

[Tidewave Connect](connect.md) includes a vision mode feature that allows the agent to capture screenshots and record videos. You can enable vision mode on the bottom left:

<img src="assets/vision-mode.png" alt="Vision mode">

Once enabled, you can copy the instructions that will guide your agent to capture screenshots or record videos accordingly:

* **Screenshots** — Enable vision mode and allow the agent to automatically spot visual regressions it would miss from code alone

* **Recordings** — Enable vision mode and allow the agent to record videos to reproduce bugs or as proof of work, with support for captioning and narration

Screenshots are always fed back into the coding agent. Videos are for your consumption (none of the supported coding agents accept videos as input).

Videos by default include overlays, animations, and sound effects (which you may ask the agent to disable). You may also opt into voice narration.

> #### Browser support {: .info}
>
> Vision mode depends on the [RestrictionTarget API](https://developer.mozilla.org/en-US/docs/Web/API/RestrictionTarget/fromElement_static#browser_compatibility), which is, at the moment, available only on Chromium based browsers (Chrome, Edge, etc).

> #### When to enable vision mode? {: .info}
>
> By default, Tidewave Connect exposes the accessibility tree of the current page as text to your coding agent. In our tests, this is the most efficient format and allows the agent to effectively use and navigate your app. Screenshots are useful when trying to understand the overall colors and themes of the page, or to fix alignment issues.

## Voice narration

You can enable voice narration, so the coding agent itself narrates the videos it records. To do so, [an ElevenLabs API key will be necessary](https://elevenlabs.io/).

The following video uses the "Voice narration" feature to show you how to enable it and how it works. It also includes animations and sound effects:

<iframe width="640" height="360" src="https://www.youtube.com/embed/U4CCBWmu2D0?si=XgMnDTWoWWhSkGwu" title="Tidewave agentic video recording + narration" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

For completeness, here is the prompt used to record the video above:

```text
Please record the following video:

overlay: This is Tidewave's video recorder.

overlay: First add your Eleven Labs API key
open up settings, focus on this element: {Selected element <div>}

overlay: Then tell your agent what to record
now close settings, focus on {Selected element <div>}
(use 2x zoom in), and type "make an awesome video!", zoom out
```

The `{Selected element <div>}` snippets are page elements selected with
our [Inspector](inspector.md) feature.

> #### ElevenLabs API key {: .info}
>
> Your API key is only kept on the client and never sent to our servers.

## Tidewave IDE

If you are using the Tidewave IDE, you can enable vision mode on the top right instead:

<img src="assets/vision-enable.png" alt="Enable vision mode" height="300px">

From now on, whenever the agent takes a screenshot or records a video, you will see thumbnails below the associated tool call:

<div>
<img src="assets/vision-screenshot.png" alt="Agentic screenshot" width="400px">
<img src="assets/vision-video.png" alt="Agentic video" width="400px">
</div>

Screenshots are always fed back into the coding agent. Videos are for your consumption (none of the supported coding agents accept videos as input).

Videos by default include overlays, animations, and sound effects (which you may ask the agent to disable). You may also opt into voice narration.

## Tips

* **Animations and sound effects** — Agentic recordings include animations and sound effects on click and on typing. For those to happen, make sure the agent is using `browser.click` and `browser.fill` in the scripts (we already instruct the agent to do so, but you may need to reinforce it in long sessions).

* **Close ups and overlays** — You can ask the agent to zoom-in and zoom-out before performing certain actions (which uses `browser.zoom`). You can also ask the agent to add overlays (via `browser.overlay`), which are also narrated when "Voice narration" is enabled.

* **Viewport pairing** — You can combine video recording with the [Viewport](connect.md#viewport) feature to control the dimensions of the recorded video. If using agentic recording, the agent is also capable of resizing the viewport. For example, you can ask the agent to record two videos, one for desktop, one for mobile. The agent can also resize while recording, which is supported by the .webm format, but not all players handle it accordingly.

* **Rehearsals** — Vision mode will first rehearse the video recording, before it actually starts, so they iron out all of the details. For highly dynamic pages and recordings, where the elements you will interact with change, the agent is instructed to use query selectors, such as IDs and labels. The agent is also instructed to clean up any changes done during rehearsals before recording. As always, we carefully instruct the agent to do so, but you may need to reinforce it in long sessions.

* **It is just JavaScript** — Our agentic recording is just JavaScript. This means that, if you want anything to happen during recording, such as highlighting an element, showing confetti, etc., you can ask the agent to do so and it should write appropriate code snippets.
