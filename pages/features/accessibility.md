# Accessibility diagnostics

The Tidewave Toolbar and Tidewave IDE can perform accessibility checks, based on the page’s content rather than source code analysis, and enrich those reports with framework metadata. Watch the video:

<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/v-R6diEc7jU?si=2wIsoR_HQUnJcrD0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Tidewave uses a technique we call Trace-Augmented Generation to ensure coding agents can be more accurate and faster when doing full-stack changes, such as fixing accessibility reports. [Read our announcement post to learn more](https://tidewave.ai/blog/improving-web-accessibility-with-trace-augmented-generation).

Tidewave also emits framework specific warnings, see [Page diagnostics](diagnostics.md) to learn more.

> #### Tidewave IDE {: .info}
>
> Accessibility diagnostics are available in the Tidewave IDE by clicking the accessibility icon on the top right. Both have the same functionality.

## Agentic accessibility reports

Whenever your coding agent is navigating your application through Tidewave Connect or Tidewave IDE, you can ask it to use the `browser_eval` tool to collect accessibility diagnostics from any page, allowing the agent to assess, debug, and fix accessibility defects automatically.
