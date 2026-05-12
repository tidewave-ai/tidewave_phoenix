# Task board

Tidewave Web includes a task board which can be used to share tasks across sessions:

![Task Board](assets/task-board.png)

Task boards are useful when you want to break a larger effort into smaller pieces and track progress across multiple sessions. For example:

  * **Planning** — describe a large goal and break it into tasks. You get a structured plan on the board that you can then delegate to different sessions.

  * **Parallel workstreams** — you can use one session to create and manage tasks, while a separate session claims and completes tasks from the same board. [Watch this walkthrough video to learn more](https://www.youtube.com/watch?v=A1_LbrZArVk).

  * **Resuming later** — close your session and come back the next day to continue right where you left off.

## Usage

To use task boards, you must assign a board to a chat before you send the first message. From that moment on, the chat knows it is attached to a Task Board, but it doesn't know the content or how many tasks. The first time you mention tasks, the agent will retrieve all necessary information (or you can explicitly ask it to do so).

Within the board, you can create, edit, or drag and drop tasks between columns, but the only way to start a task is by asking the agent to work on it.

You can also ask the agent to create or modify tasks on your behalf. You can click the "quote" icon on the top right of the cards to reference them in the chat. If you want to refine a particular section of a task, select which part you want to change and click "Reference in prompt". Tidewave will send the task and that particular section to the agent:

<img src="assets/task-board-select.png" alt="Reference in prompt" width="400">

Finally, it is possible to archive tasks, which can be particularly useful when you have too many entries in the "Completed" column.

## Limitations

Task boards have the following limitations:

  * You cannot swap or remove the assigned task board after the session starts

  * Task boards have been modelled after Claude Code tasks. When using Claude Code, Tidewave relies on the built-in Claude Code tools. When using other agents, Tidewave injects its own board management tools. For this reasons and in order to enable cross-agent compability, task boards are stored in your `~/.claude/tasks` folder, regardless of the coding agent you are using
