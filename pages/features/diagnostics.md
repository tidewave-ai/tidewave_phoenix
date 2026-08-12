# Page Diagnostics

When your app runs in Tidewave IDE or uses the Tidewave Toolbar, Tidewave watches it for runtime problems and reports them in the Diagnostics panel. Reports can come from your web framework or from uncaught JavaScript errors and unhandled promise rejections.

Unlike static analysis, diagnostics are collected while you use the app. This means Tidewave can report problems with the exact page and elements that triggered them, including framework metadata when it is available.

## Usage

Open the Diagnostics panel by clicking the diagnostics icon. A badge on the icon shows the number of collected reports.

![IDE diagnostics](assets/diagnostics-ide.png)

![Toolbar diagnostics](assets/diagnostics-toolbar.png)

Each report includes the source, diagnostic type, severity, and a description of the problem. When a report identifies affected elements, hover an element button to highlight it on the page. Tidewave also attaches the element's selector and framework rendering information to the report, helping the coding agent find the relevant source code.

You can select individual reports if you only want to address some of them. By default, all diagnostics are selected.

* In Tidewave IDE, click **Fix issues** to send the selected reports directly to your coding agent.

* In the Toolbar, click **Copy prompt to fix issues**, then paste the resulting prompt into your coding agent.

Click **Clear** to remove the collected reports. Clearing a report does not fix or suppress the underlying problem, so it will appear again if the app triggers it again.

## JavaScript diagnostics

For every supported framework, Tidewave reports uncaught JavaScript errors and unhandled promise rejections. When available, the report includes a source-mapped stack trace so the coding agent can trace the failure back to application source code.

## Framework integration

Framework integrations add structured, actionable reports that are not available from JavaScript exceptions alone. For example, Tidewave can associate a problem with affected DOM elements and enrich those elements with server-side template or component information.

For example, for Rails applications, Tidewave also reports uncaught errors from Stimulus and identifies the affected element when Stimulus provides one.

### Phoenix LiveView diagnostics

Tidewave turns application-level diagnostics emitted by Phoenix LiveView into reports with a suggested fix. It currently recognizes problems involving, among others:

* Duplicate DOM IDs, invalid stream containers, invalid children of `phx-update` containers, and form inputs named `id`

* Invalid DOM bindings, like `phx-debounce` / `phx-throttle` values, or `phx-target` selectors that do not match an element

* Hooks that are missing an ID, unknown, invalid, attached to a disconnected element, or fail during initialization

* Invalid colocated hooks and custom elements that do not create their hook after connecting to the DOM

* Missing or duplicate LiveView upload inputs

When LiveView includes elements in a diagnostic, Tidewave adds their selectors and HEEx component information to the prompt. Enable `debug_heex_annotations` and `debug_attributes` in your Phoenix development configuration to get the most precise source information.

#### Validate LiveView navigation

Live navigation can appear to work while depending on transient socket state that will not exist when someone opens, refreshes, or bookmarks the resulting URL. Tidewave detects this by fetching each same-origin URL reached through LiveView navigation and checking that it can also load directly.

This check is enabled by default. You can turn it on or off under **Settings > Diagnostics > Validate LiveView navigation** or by  clicking **Configure** in the Diagnostics panel.

If the direct request fails or returns a non-successful response, Tidewave creates a diagnostic with the HTTP or Phoenix error details. The report guides the coding agent to ensure that `mount/3` and `handle_params/3` reconstruct the required assigns from the URL, session, or persistent data instead of relying on state established by `handle_event/3`.
