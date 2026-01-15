# Editors/IDEs

Tidewave can open up files and page elements directly in your editor.

Whenever Tidewave renders a file location, you can directly click the filename to open it in your editor. They will be identified with an upward right facing arrow (↗):

<img src="assets/file-editor.png" alt="File editor integration" width="400px">

When you click the filename for the first time, Tidewave will open up the "Editor integration" pane on Settings, where you can choose between a few preset editors, or set up a custom URL or a custom command.

You can also use our editor integration alongside the [Inspector](inspector.md). Ctrl+Click or Cmd+Click (macOS) an element with the Inspector enabled will automatically open it in your editor.

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