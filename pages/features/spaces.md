# Spaces

Spaces allows you to connect a single Tidewave Web tab to multiple web applications and manage multiple coding agents side-by-side. They may be different instances of the same application or even different applications altogether.

<img src="assets/spaces-idle.png" alt="Spaces, all idle" width="300px">

## Use cases

Today, developers who want to run multiple coding agents at once in the same application, have different choices available to them:

* They can clone their repositories to different directories and alternate between them

* They can use tools such as [worktrunks](https://worktrunk.dev/) to create and manage Git worktrees

* They can use multiple containers, either local via Docker or remotely

Our goal with Spaces is not to prescribe a given workflow, rather integrate with your existing practices. For example:

* You can clone your web app to three different directories, run each of them on a separate port, such as 4000, 4001, and 4002, and connect Tidewave to each. No worktrees or additional tools needed.

* You can use `worktrunks` to automatically configure worktrees and spawn a web server on a different port for each of them. Then connect Tidewave to it.

* For containers, either local or remote, you can use [Tidewave's Remote Access](../remote_access.md)

All Tidewave Web needs is the port your web application is running on and you are good to go. You can also connect to unrelated web applications too and Tidewave will neatly organize them in the sidebar.

## Status indicators

Spaces have three status indicators:

* Blue - the space is busy doing work
* Green - the space has completed the current task
* Yellow - the space is blocked on your input

You can see the status of each space on the sidebar. And the sidebar icon will show the reflect the color with highest priority:

<img src="assets/spaces-status.png" alt="Spaces, with different statuses" width="300px">
