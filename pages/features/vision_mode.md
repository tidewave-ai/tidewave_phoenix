# Vision mode

Vision mode allows you and the agent to capture screenshot and record videos:

* **User screenshots** — Attach screenshots in your prompts via the `@` menu and give the agent more context

* **Agentic screenshots** — Enable vision mode and allow the agent to automatically spot visual regressions it would miss from code alone

* **User recordings** — Record videos of your application to include in pull requests and ease the review process

* **Agentic recordings** — Enable vision mode and allow the agent to record videos as proof of work or reproducing bugs

Vision mode depends on the [RestrictionTarget API](https://developer.mozilla.org/en-US/docs/Web/API/RestrictionTarget/fromElement_static#browser_compatibility), which is, at the moment, available only on Chromium based browsers (Chrome, Edge, etc).

> #### When to enable vision mode? {: .info}
>
> By default, Tidewave exposes the accessibility tree of the current page as text to your coding agent. In our tests, this is the most efficient format and allows the agent to effectively use and navigate your app. Screenshots are useful when trying to understand the overall colors and themes of the page, or to fix alignment issues.

## Video recordings

You can record your own videos by selecting "Record your app" in the vision mode menu:

<img src="assets/vision-record-app.png" alt="Enable vision mode" height="300px">

Once enabled, it will ask permission to record the current tab.

Video recordings are stored in disk. You can select "View recordings" to list all of them inside Tidewave or "Open recordings directory" to open it within your operating system.

The Tidewave team itself makes extensive use of video recordings. Almost every pull request we submit includes a video recording, recorded by humans or agents, which smooths the review process. Whenever you record a video, a toast will appear on the top-right, allowing you to view the video, reveal its location in disk, or list all of them:

<img src="assets/vision-new-recording.png" alt="Agentic video" width="500px">

## Agentic use

You can enable your agent to automatically take screenshots and record videos within your browser by toggling vision mode:

<img src="assets/vision-enable.png" alt="Enable vision mode" height="300px">
  
Once enabled, it will ask permission to record the current tab.

From now on, whenever the agent takes a screenshot or record a video, you will see thumbnails below the associated tool call:

<div>
<img src="assets/vision-screenshot.png" alt="Agentic screenshot" width="400px">
<img src="assets/vision-video.png" alt="Agentic video" width="400px">
</div>

Screenshots are always fed back into the coding agent. Videos are for your own use only (none of the supported coding agents accept videos as input).

### Voice narration

You can enable voice narration, so the coding agent itself narrate the videos it records. To do so, [an ElevenLabs API key will be necessary](https://elevenlabs.io/).

The following video uses the "Voice narration" feature to show you how to enable it and how it works:

<iframe width="640" height="360" src="https://www.youtube.com/embed/U4CCBWmu2D0?si=XgMnDTWoWWhSkGwu" title="Tidewave agentic video recoding + narration" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

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

### Tips

* **Animations and sound effects** — Agentic recordings include animations and sound effects on click and on typing. For those to happen, make sure the agent is using `browser.click` and `browser.fill` in the scripts (we already instruct the agent to do so, but you may need to reinforce it in long sessions).

* **Close ups and overlays** — You can ask the agent to zoom-in and zoom-out before performing certain actions (which uses `browser.zoom`). You can also ask the agent to add overlays (via `browser.overlay`), which are also narrated when "Voice narration" is enabled.

* **Viewport pairing** — You can combine video recording with the [Viewport](viewport.md) feature to control the dimensions of the recorded video. If using agentic recording, the agent is also capable of resizing the viewport. For example, you can ask the agent to record two videos, one for desktop, one for mobile. The agent can also resize while recording, which is supported by the .webm format, but not all players handle it accordingly.

* **Rehearsals** — Vision mode will first rehearse the video recording, before it actually starts, so they iron out all of the details. For highly dynamic pages and recordings, where the elements you will interact with change, the agent is instructed to use query selectors, such as IDs and labels. The agent is also instructed to clean up any changes done during rehearsals before recording. As always, we carefully instruct the agent to do so, but you may need to reinforce it in long sessions.

* **It is just JavaScript** — Our agentic recording is just JavaScript. This means that, if you want anything to happen during recording, such as highlighting an element, showing confetti, etc., you can ask the agent to do so and it should write appropriate code snippets.
