# Editors/IDEs

Tidewave Web can open up files and page elements directly in your editor.

Whenever Tidewave renders a file location, you can directly `Ctrl+Click` (or `Cmd+Click`) the filename to open it in your editor. They will be identified with an upward right facing arrow (↗):

<img src="assets/file-editor.png" alt="File editor integration" width="400px">

When you click the filename for the first time, Tidewave will open up the "Editor integration" pane on Settings, where you can choose between a few preset editors, or set up a custom URL or a custom command.

There are a few additional places you can open in editor:

* In the [Inspector](../features/inspector.md), `Ctrl+Click` (or `Cmd+Click`) an element pointed by the inspector to open its source

* Whenever viewing a file or a diff during [Code Review](../features/code_review.md), you can `Ctrl+Click` (or `Cmd+Click`) the line number of open up the file at that location

## Custom URLs (or custom commands)

Tidewave Web come with built-in support for a few editors.
In case your editor is not supported, you can use a custom URL
or a custom command. For example, if you are using one of JetBrains
IDEs, you may configure a custom URL like this:

```
idea://open?file=__FILE__&line=__LINE__
pycharm://open?file=__FILE__&line=__LINE__
```

## Container configuration

You can also run Tidewave Web inside containers. However,
when running inside containers, the file paths in the container won't align
with the paths on the host machine. For this purpose, Tidewave allows setting
the `TIDEWAVE_HOST_PATH` environment variable in your container, which should
point to the path the project is located on your machine. When launching the
container from the project's root directory, you can set it to the output of
`pwd`. In Docker, for example, that would be:

```bash
docker run -e TIDEWAVE_HOST_PATH=$(pwd) ...
```