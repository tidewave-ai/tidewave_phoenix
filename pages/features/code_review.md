# Code review

You can review code, in real-time, with Tidewave Web.

<iframe width="640" height="360" src="https://www.youtube.com/embed/vdMetEO7K4Q?si=xcGqoOIXwtR-7QCy" title="Tidewave Code Review" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Our code review is designed around two main workflows:

* **Intercalated reviews** — in this scenario, the coding agent does the work in the background, and the developer reviews the work when the agent is done. During the review, you may request additional changes, which may require additional reviews

* **Real-time reviews** — in this scenario, you review the code as the coding agent is working, immediately giving the agent feedback

Tidewave Web enables both by updating the code review pane in real-time and allowing you to mark which code sections (hunks in `git` terms) have been reviewed:

<img src="assets/review-review.png" alt="Code review: review / unreviewed" width="600px">

Future changes show as diffs on top of what you've already reviewed, so you no longer end-up reviewing the same code multiple times, regardless if you are working in tandem with the agent (real-time) or reviewing it once it is done.

Within the code review pane, you can also comment on any change and send it to your agent as feedback, either immediately or queued up for when it finishes its current turn:

<img src="assets/review-comment.png" alt="Code review: comments" width="600px">

Once you have reviewed your changes, you can click the "Commit reviewed" button on the top right or choose an alternative:

* **Commit reviewed** - it will stage all reviewed changes and ask the agent to commit them
* **Commit all** - it will stage all changes and ask the agent to commit them
* **Stage reviewed** - it will stage all reviewed changes

If you ask the agent to commit and you are in your default branch (typically `main`), Tidewave will ask prompt if you want to create a new branch.

All commits done by Tidewave will append a "Assisted-by: Model Version Tidewave" line to the commit message. You can disable this behaviour or provide custom commit and branch naming instructions in Settings.

> #### Opening up diffs and files in your editor {: .tip}
>
> If you `Ctrl+Click` (or `Cmd+Click`) a line number, either within the code review or while viewing a file, Tidewave will automatically open up that file+line in your editor of choice.

## Configuration

We currently support both unified and split diffs and have an option to wrap lines. Click on the `⋮` button on the top-right to configure it:

<img src="assets/review-config.png" alt="Code review: configuration" width="450px">

## Git integration

You can swap branches, push/pull, and more [from the Git bar](git.md).