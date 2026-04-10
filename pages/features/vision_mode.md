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

## Agentic use

You can enable vision mode on the top right. Enabling it will give your agent the ability to take screenshots and record videos within your browser. Once enable, it will ask permission to record the current tab:

<img src="assets/vision-enable.png" alt="Enable vision mode" height="300px">
  
Whenever the agent takes a screenshot or record a video, you will see thumbnails below the associated tool call:

<div>
<img src="assets/vision-screenshot.png" alt="Agentic screenshot" width="400px">
<img src="assets/vision-video.png" alt="Agentic video" width="400px">
</div>

Screenshots are always fed back into the coding agent. Videos are for your own use only (none of the supported coding agents accept videos as input).

## Video recordings

Video recordings are stored in disk. You can select "View recordings" to list all of them inside Tidewave or "Open recordings directory" to open it within your operating system.

The Tidewave team itself makes extensive use of video recordings. Almost every pull request we submit includes a video recording, recorded by humans or agents, which smooths the review process. Whenever you record a video, a toast will appear on the top-right, allowing you to view the video, reveal its location in disk, or list all of them:

<img src="assets/vision-new-recording.png" alt="Agentic video" width="500px">

## Tips

You can combine video recording with the [Viewport](viewport.md) feature to control the dimensions of the recorded video. If using agentic recording, the agent is also capable of resizing the viewport. For example, you can ask the agent to record two videos, one for desktop, one for mobile. The agent can also resize while recording, which is supported by the .webm format, but not all players handle it accordingly.
