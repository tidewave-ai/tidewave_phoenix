# Inspector

Tidewave includes a default inspector integrated with our coding agent. The Inspector understands both server-side templates and client-side components.

## Usage

You can find the inspector on the top right of your browser window. Once enabled, you can hover page elements:

![Inspector example](assets/inspector.png)

Once you click an element, the chat box will show an element is currently inspected:

<img src="assets/inspecting.png" alt="Update chat with inspected element" width="400px">

If you send a message, Tidewave will include precise information about that element, such as its location on the page, part of its contents, as well as the server-side templates and client components involved in rendering the particular element.

## Framework overlay

By holding the `Ctrl` key (or `Cmd` key on macOS) while the Inspector is enabled. We will automatically show template/component metadata in a purple overlay. See the video below:

<iframe width="640" height="360" src="https://www.youtube.com/embed/7bYxfcgaisc?si=R_V5_RF_Vd-rJpvr" title="Tidewave Web Framework Overlay" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Clicking the element while the `Ctrl` key (or `Cmd` key on macOS) are pressed will open up the template/component in your [configured editor](editors.md).

## Shortcuts

The inspector supports the following shortcuts:

* `Ctrl+Click` or `Cmd+Click` (macOS): when hovering an element, you may Ctrl+Click it, and Tidewave will open up the element in your editor using your configured [editor integration](editors.md)

* `Escape`: disables the Inspector