# Running Tidewave in CI

Tidewave can be integrated into your CI runs using Tidewave Connect and an existing agent harness like Anthropic's [`claude-code-action`](https://github.com/anthropics/claude-code-action) or OpenAI's [`codex-action`](https://github.com/openai/codex-action). This guide explores setting up both in a GitHub Actions environment. For other CI systems or custom browser launchers, see [Manual setup](#manual-setup).

## Why use Tidewave in CI?

Tidewave gives your CI agent access to the running application and a real browser. This lets it reproduce reported bugs, run Accessibility and Web Framework diagnostics, and verify its changes through videos and screenshots before replying to an issue or pull request.

* **Browser access**: The agent can navigate pages, click buttons, fill forms, and inspect the rendered app through [Tidewave's browser automation](connect.md).
* **Runtime context**: The agent can evaluate code inside the running application to investigate its behavior. [Page diagnostics](diagnostics.md) also surface framework and JavaScript errors as it navigates, helping it connect browser failures to their source.
* **Visual verification**: With [vision mode](vision_mode.md), the agent can inspect screenshots for layout issues and capture screenshots or videos to show what it tested. The examples below explain how to include that media in GitHub comments.

## GitHub Actions

The workflows below assume a Phoenix application with Tidewave installed, PostgreSQL, and a `mix setup` alias. Adjust the app setup and port for your project. If you are using another framework or database, you can ask your coding agent to adapt the steps below.

The Claude workflow and the full Codex workflow at the end of this guide are triggered for every newly created issue. All examples also listen for newly created comments. The agent jobs check for `@claude` or `/tidewave` respectively before running. If your repository is publicly accessible, consider restricting who can trigger these jobs, for example by adding a job-level `if` condition that checks `github.event.sender.login`.

You must store your Tidewave Connect key as `TIDEWAVE_CONNECT_KEY`.

### Vision mode support

Both agents can use [Tidewave's vision mode](vision_mode.md) to inspect the app, capture screenshots, and record videos. However, GitHub Actions' `GITHUB_TOKEN` and GitHub App installation tokens currently cannot upload media attachments to issue or pull request comments ([GitHub CLI issue #14309](https://github.com/cli/cli/issues/14309)). Posting screenshots or videos alongside the agent's answer requires a personal access token (PAT). Vision mode itself works without one.

For media attachments, we recommend a separate bot user with write access to only the repositories it needs. Create a fine-grained PAT for that user, restrict it to those repositories, and grant these repository permissions:

| Permission | Access | Purpose |
| --- | --- | --- |
| Issues | Read and write | Post issue comments. |
| Pull requests | Read and write | Post pull request comments. |
| Contents | Read | Read the repository. |

Store the PAT as the `GH_COMMENT_TOKEN` repository secret.

GitHub CLI's attachment uploader requires the bot user to have write access to the repository. This is separate from the PAT's Contents permission, which can remain read-only for these examples. The workflows use it outside the agent for GitHub operations such as checking PR ownership, posting media, and opening pull requests.

## Claude Code

This workflow is adjusted based on [the official Anthropic example](https://github.com/anthropics/claude-code-action/blob/main/examples/claude.yml). Install the [Claude GitHub App](https://github.com/apps/claude) for your repository and add `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` as a repository secret. Save the workflow as `.github/workflows/claude.yml`, then mention `@claude` in an issue or pull request comment to run it.

See also [the Claude Code GitHub Actions documentation](https://code.claude.com/docs/en/github-actions).

<!-- tabs-open -->

### Without media attachments

Claude uses Tidewave to inspect and verify the app and posts its answer using the Claude GitHub App. No personal access token is needed.

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  claude:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||
      (github.event_name == 'issues' && (contains(github.event.issue.body, '@claude') || contains(github.event.issue.title, '@claude')))
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
      actions: read # Required for Claude to read CI results on PRs
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          fetch-depth: 1
          # Start the server on the PR code, not the default branch, so it matches what Claude checks out
          ref: ${{ github.event.issue.pull_request && format('refs/pull/{0}/head', github.event.issue.number) || github.event.pull_request.head.sha || '' }}

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19"
          otp-version: "28"

      - name: Cache deps and build
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-dev-${{ hashFiles('mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-dev-

      - name: Set up the app
        run: mix setup

      # Tidewave is a dev-only dependency, so the server runs in the dev environment
      # The loop restarts the server whenever it exits, so the agent can restart it
      - name: Start the app
        run: |
          mkdir -p tmp
          (while true; do
            mix phx.server || echo "The app exited with status $?"
            echo "Restarting the app"
            sleep 1
          done) > tmp/app.log 2>&1 &

      - name: Connect Tidewave
        id: tidewave
        uses: tidewave-ai/connect-action@v1
        with:
          app_url: http://localhost:4000
          connect_key: ${{ secrets.TIDEWAVE_CONNECT_KEY }}

      - name: Run Claude Code
        id: claude
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # Uncomment to use API key instead
          # anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          claude_args: |
            --mcp-config '{"mcpServers": {"tidewave": {"type": "http", "url": "${{ steps.tidewave.outputs.mcp_url }}"}}}'
            --allowedTools 'mcp__tidewave,Bash(mix:*),Bash(MIX_ENV=test mix:*)'
            --append-system-prompt 'The app is running at http://localhost:4000 with Tidewave, in the dev environment. Use the Tidewave MCP tools to evaluate code in the app and to verify your changes in the browser. It reloads code changes automatically, so do not start another server with mix phx.server. The server log is in tmp/app.log. Run mix precommit before you finish and fix any issues it reports.

            If you add a migration, run mix ecto.migrate. The app does not need a restart for this.

            If you change config files or add dependencies, restart the app:
            1. Run mix do deps.get + compile and fix any errors.
            2. Call System.stop() with the Tidewave project_eval tool. The workflow starts the app again automatically.
            3. The Tidewave tools are unavailable until the app is back up, which can take a few seconds. Wait and retry. If the app does not come back, check tmp/app.log.'

      - name: Upload app log
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: app-log
          path: tmp/app.log
          if-no-files-found: ignore
```

### With media attachments

Start with the workflow in **Without media attachments** and configure the bot user's `GH_COMMENT_TOKEN` as described above. Append the following instructions inside the quoted `--append-system-prompt` value:

```text
If you capture screenshots or recordings with Tidewave, save them under tmp/tidewave/.
After you finish, a later workflow step uploads the images and videos from that
directory and posts them in a separate comment, so do not post them yourself.
You can write tmp/tidewave/report.md to use as the body of that comment.
Reference each file by its path, such as ![The settings page](tmp/tidewave/screenshots/settings.png),
and it is replaced with the uploaded URL. To embed a video as a player, put its
reference, such as ![](tmp/tidewave/recordings/flow.webm), alone in its own paragraph.
Files you do not reference are appended at the end.
```

Add this step after **Run Claude Code**, before **Upload app log**. It uses the official GitHub CLI with `gh issue comment --attach` and `gh pr comment --attach`:

```yaml
      - name: Post Tidewave screenshots and videos
        if: ${{ !cancelled() }}
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          KIND: ${{ (github.event.issue.pull_request || github.event.pull_request) && 'pr' || 'issue' }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number || github.event.pull_request.number }}
        run: |
          shopt -s nullglob globstar nocaseglob
          files=(tmp/tidewave/**/*.{png,jpg,jpeg,gif,webp,webm,mp4,mov})
          if [ ${#files[@]} -eq 0 ]; then
            echo "No Tidewave screenshots or recordings to post"
            exit 0
          fi

          args=()
          if [ -f tmp/tidewave/report.md ]; then
            args+=(--body-file tmp/tidewave/report.md)
          else
            args+=(--body "### Tidewave screenshots and videos")
          fi
          for f in "${files[@]}"; do args+=(--attach "$f"); done

          gh "$KIND" comment "$NUMBER" "${args[@]}"
```

<!-- tabs-close -->

## Codex

The [`@codex` GitHub integration](https://developers.openai.com/codex/integrations/github) handles hosted reviews and cloud tasks. It does not trigger `openai/codex-action` on your runner. This example uses a custom `/tidewave` command instead: post `/tidewave <your request>` as an issue or pull request conversation comment.

The Codex action runs the CLI with a prompt and returns its final answer. The workflow must collect the request and issue or PR context, configure the Tidewave MCP server, and post the answer itself. Add `OPENAI_API_KEY` as a repository secret and save the workflow as `.github/workflows/codex.yml` on your default branch so `issue_comment` can trigger it. You can add more triggers and adjust the workflow to your need as necessary.

<!-- tabs-open -->

### Without media attachments

This workflow posts a text answer with `GITHUB_TOKEN`, so no personal access token is needed. For pull request comments, it checks out the pull request's code before starting the app.

```yaml
name: Codex with Tidewave

on:
  issue_comment:
    types: [created]

jobs:
  codex:
    if: |
      startsWith(github.event.comment.body, '/tidewave ')
    # https://github.com/openai/codex-action/issues/188
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      issues: write
      pull-requests: write
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          fetch-depth: 1
          persist-credentials: false
          ref: ${{ github.event.issue.pull_request && format('refs/pull/{0}/head', github.event.issue.number) || github.event.repository.default_branch }}

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19"
          otp-version: "28"

      - name: Cache deps and build
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-dev-${{ hashFiles('mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-dev-

      - name: Set up the app
        run: mix setup

      # Tidewave is a dev-only dependency, so the server runs in the dev environment
      # The loop restarts the server whenever it exits, so the agent can restart it
      - name: Start the app
        run: |
          mkdir -p tmp
          (while true; do
            mix phx.server || echo "The app exited with status $?"
            echo "Restarting the app"
            sleep 1
          done) > tmp/app.log 2>&1 &

      - name: Connect Tidewave
        id: tidewave
        uses: tidewave-ai/connect-action@v1
        with:
          app_url: http://localhost:4000
          connect_key: ${{ secrets.TIDEWAVE_CONNECT_KEY }}

      - name: Prepare Codex prompt
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
          KIND: ${{ github.event.issue.pull_request && 'pr' || 'issue' }}
          REQUEST: ${{ github.event.comment.body }}
        run: |
          gh "$KIND" view "$NUMBER" --json title,body,comments > tmp/tidewave-context.json
          if [ "$KIND" = pr ]; then
            gh pr diff "$NUMBER" > tmp/tidewave-pr.diff
          fi
          cat > tmp/codex-prompt.md <<'PROMPT'
          Read tmp/tidewave-context.json for the issue or pull request context.
          For a pull request, also read tmp/tidewave-pr.diff.
          Follow the request below and summarize your changes and verification in
          your final answer. A later workflow step posts that answer to GitHub.

          The app is running at http://localhost:4000 with Tidewave, in the dev environment. Use the Tidewave MCP tools to evaluate code in the app and to verify your changes in the browser. It reloads code changes automatically, so do not start another server with mix phx.server. The server log is in tmp/app.log. Run mix precommit before you finish and fix any issues it reports.

          If you add a migration, run mix ecto.migrate. The app does not need a restart for this.

          If you change config files or add dependencies, restart the app:
          1. Run mix do deps.get + compile and fix any errors.
          2. Call System.stop() with the Tidewave project_eval tool. The workflow starts the app again automatically.
          3. The Tidewave tools are unavailable until the app is back up, which can take a few seconds. Wait and retry. If the app does not come back, check tmp/app.log.

          PROMPT
          printf '\nRequest:\n%s\n' "$REQUEST" >> tmp/codex-prompt.md

      - name: Configure Codex
        env:
          CODEX_CONFIG_DIR: ${{ runner.temp }}/tidewave-codex
        run: |
          mkdir -p "$CODEX_CONFIG_DIR"
          cat > "$CODEX_CONFIG_DIR/config.toml" <<'CONFIG'
          [mcp_servers.tidewave]
          url = "${{ steps.tidewave.outputs.mcp_url }}"
          required = true
          default_tools_approval_mode = "approve"

          [permissions.tidewave]
          extends = ":workspace"

          [permissions.tidewave.network]
          enabled = true
          CONFIG

      - name: Run Codex
        id: codex
        uses: openai/codex-action@v1
        with:
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
          prompt-file: tmp/codex-prompt.md
          output-file: tmp/codex-answer.md
          codex-home: ${{ runner.temp }}/tidewave-codex
          permission-profile: tidewave
          safety-strategy: drop-sudo

      - name: Post Codex answer
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
          KIND: ${{ github.event.issue.pull_request && 'pr' || 'issue' }}
        run: gh "$KIND" comment "$NUMBER" --body-file tmp/codex-answer.md

      - name: Upload app log
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: app-log
          path: tmp/app.log
          if-no-files-found: ignore
```

The MCP configuration sets `default_tools_approval_mode = "approve"` to [preapprove Tidewave's tool calls](https://learn.chatgpt.com/docs/extend/mcp#other-configuration-options), since CI cannot answer interactive approval prompts. Network access in the permission profile does not grant MCP tool approval. Setting `required = true` makes Codex fail at startup if it cannot connect to Tidewave.

The custom [permission profile](https://developers.openai.com/codex/permissions) enables network access so Codex can reach the running app and database and install dependencies when needed. This example reports its work in a comment. To publish code changes, see [Opening pull requests with a bot user](#opening-pull-requests-with-a-bot-user).

### With media attachments

Start with the workflow in **Without media attachments** and configure the bot user's `GH_COMMENT_TOKEN` as described above. Add these instructions to the prompt in **Prepare Codex prompt**, before the closing `PROMPT` marker:

```text
Save screenshots and recordings under tmp/tidewave/. In your final answer, reference
each file by its path, such as ![The settings page](tmp/tidewave/screenshots/settings.png).
The workflow uploads the files and replaces these references with attachment URLs.
To embed a video as a player, put its reference, such as ![](tmp/tidewave/recordings/flow.webm),
alone in its own paragraph. Do not post the answer or upload the media yourself.
```

Replace **Post Codex answer** with the following step. It uses the PAT to post the answer and attach any captured images or videos in the same comment. It requires a GitHub CLI version with `--attach` support:

```yaml
      - name: Post Codex answer with media
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
          KIND: ${{ github.event.issue.pull_request && 'pr' || 'issue' }}
        run: |
          shopt -s nullglob globstar nocaseglob
          files=(tmp/tidewave/**/*.{png,jpg,jpeg,gif,webp,webm,mp4,mov})
          args=(--body-file tmp/codex-answer.md)
          for f in "${files[@]}"; do args+=(--attach "$f"); done

          gh "$KIND" comment "$NUMBER" "${args[@]}"
```

<!-- tabs-close -->

### Opening pull requests with a bot user

You can extend the Codex workflow to implement requests on issues and open new pull requests against the default branch. The agent edits files and verifies them with Tidewave. A separate publishing job applies those changes to a fresh checkout, commits them, pushes a branch, and opens a pull request as your bot user.

Use the bot user's `GH_COMMENT_TOKEN` configured above. The publishing job pushes with `GITHUB_TOKEN`, so the PAT only needs Contents read, Issues read and write, and Pull requests read and write. Codex does not receive the bot token.

Start with the Codex workflow above. Update its job condition to handle issue comments and add outputs for the starting commit and whether there are changes:

```yaml
    # Under jobs.codex:
    if: |
      !github.event.issue.pull_request &&
      startsWith(github.event.comment.body, '/tidewave ')
    outputs:
      base_sha: ${{ steps.base.outputs.sha }}
      changes: ${{ steps.changes.outputs.present }}
```

Immediately after **Checkout repository**, record the starting commit and exclude generated files under `tmp/` from Git:

```yaml
      - name: Record base commit
        id: base
        run: |
          echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
          printf '/tmp/\n' >> .git/info/exclude
```

Add these instructions to **Prepare Codex prompt**, before the closing `PROMPT` marker:

```text
Only change code when the request asks you to implement or fix something.
Leave your edits in the working tree: do not commit, create branches, push,
or open a pull request. Do not change files under .github/.
If you change code, write a short pull request title on one line in
tmp/tidewave/pr-title.txt. Your final answer will be the pull request body:
explain the changes and how you verified them.
```

After **Run Codex**, collect the changes into a binary patch, including any new files. This runs outside Codex's sandbox, so the agent does not need permission to write to `.git`. The artifact also includes its answer, PR title, and any media saved under `tmp/tidewave/`:

```yaml
      - name: Collect changes
        id: changes
        env:
          BASE_SHA: ${{ steps.base.outputs.sha }}
        run: |
          set -euo pipefail
          bundle="$RUNNER_TEMP/tidewave-changes"
          mkdir -p "$bundle/tmp"
          git add --all -- .
          git diff --cached --binary "$BASE_SHA" > "$bundle/changes.patch"
          if [ ! -s "$bundle/changes.patch" ]; then
            exit 0
          fi
          test -s tmp/tidewave/pr-title.txt
          cp tmp/codex-answer.md "$bundle/body.md"
          cp -R tmp/tidewave "$bundle/tmp/"
          echo "present=true" >> "$GITHUB_OUTPUT"

      - name: Upload changes
        if: steps.changes.outputs.present == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: tidewave-changes
          path: ${{ runner.temp }}/tidewave-changes
```

Keep **Post Codex answer** to report the result on the issue, including requests that produce no code changes. Add the following job alongside `codex`. It checks out the exact starting commit and applies the patch without running the app or its build scripts:

```yaml
  publish:
    needs: codex
    if: needs.codex.outputs.changes == 'true'
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          ref: ${{ needs.codex.outputs.base_sha }}

      - name: Download changes
        uses: actions/download-artifact@v4
        with:
          name: tidewave-changes
          path: ${{ runner.temp }}/tidewave-changes

      - name: Commit and push changes
        id: push
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
        run: |
          set -euo pipefail
          bundle="$RUNNER_TEMP/tidewave-changes"
          git apply --index "$bundle/changes.patch"
          if ! git diff --cached --quiet -- .github; then
            echo "Changes to .github/ are not allowed in this workflow"
            exit 1
          fi
          read -r bot_id bot_login < <(gh api user --jq '[.id, .login] | @tsv')
          title="$(head -n 1 "$bundle/tmp/tidewave/pr-title.txt")"
          branch="bot/tidewave-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
          git switch -c "$branch"
          git -c core.hooksPath=/dev/null \
            -c user.name="$bot_login" \
            -c user.email="${bot_id}+${bot_login}@users.noreply.github.com" \
            commit -m "$title"
          git push origin "HEAD:refs/heads/$branch"
          echo "branch=$branch" >> "$GITHUB_OUTPUT"

      - name: Open pull request as the bot
        working-directory: ${{ runner.temp }}/tidewave-changes
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          GH_REPO: ${{ github.repository }}
          BASE_REF: ${{ github.event.repository.default_branch }}
          BRANCH: ${{ steps.push.outputs.branch }}
          NUMBER: ${{ github.event.issue.number }}
        run: |
          set -euo pipefail
          title="$(head -n 1 tmp/tidewave/pr-title.txt)"
          printf '\n\nRefs #%s\n' "$NUMBER" >> body.md
          url="$(gh pr create --base "$BASE_REF" --head "$BRANCH" \
            --title "$title" --body-file body.md)"
          gh issue comment "$NUMBER" --body "I opened $url with the changes."
```

To include media in the PR description, add the media instructions from **With media attachments** to the Codex prompt. In **Open pull request as the bot**, replace the `url=...` assignment with:

```bash
shopt -s nullglob globstar nocaseglob
files=(tmp/tidewave/**/*.{png,jpg,jpeg,gif,webp,webm,mp4,mov})
attachments=()
for f in "${files[@]}"; do attachments+=(--attach "$f"); done
url="$(gh pr create --base "$BASE_REF" --head "$BRANCH" \
  --title "$title" --body-file body.md "${attachments[@]}")"
```

The bot token makes the bot the PR author and lets `pull_request` workflows run automatically, subject to your repository's policies. The branch push uses `GITHUB_TOKEN`, which does not trigger `push` workflows. To trigger those too, use a bot PAT with Contents read and write as the publishing job's checkout `token`. See [GitHub's documentation on triggering workflows from workflows](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).

The full workflow below runs when you open an issue with `/tidewave` in its title or description, or add a `/tidewave <your request>` comment to an issue. It also handles these conversation comments on the PRs it creates. It checks that the PR is open, authored by the bot user, and uses a `bot/tidewave-` branch in the same repository before checking out its code. Changes requested on an issue open a new PR; follow-up changes on a bot PR are pushed to its existing branch and reported in a comment. Requests without code changes receive an answer and any media directly on the issue or PR.

Save it as `.github/workflows/codex.yml` on your default branch and configure the `TIDEWAVE_CONNECT_KEY`, `OPENAI_API_KEY`, and bot user's `GH_COMMENT_TOKEN` repository secrets as described above. Follow-up pushes use `GITHUB_TOKEN`, so `pull_request` checks may require approval, as explained above.

```yaml
name: Codex with Tidewave and bot pull requests

on:
  issues:
    types: [opened]
  issue_comment:
    types: [created]

concurrency:
  group: tidewave-${{ github.workflow }}-${{ github.event.issue.number }}
  cancel-in-progress: false

jobs:
  codex:
    if: |
      (github.event_name == 'issues' &&
        (contains(github.event.issue.title, '/tidewave') || contains(github.event.issue.body, '/tidewave'))) ||
      (github.event_name == 'issue_comment' && startsWith(github.event.comment.body, '/tidewave '))
    outputs:
      base_sha: ${{ steps.base.outputs.sha }}
      branch: ${{ steps.task.outputs.branch }}
      kind: ${{ steps.task.outputs.kind }}
      changes: ${{ steps.changes.outputs.present }}
    # https://github.com/openai/codex-action/issues/188
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      issues: write
      pull-requests: write
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - name: Resolve task
        id: task
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
          IS_PR: ${{ github.event.issue.pull_request && 'true' || 'false' }}
          DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}
        run: |
          set -euo pipefail
          if [ "$IS_PR" = false ]; then
            echo "kind=issue" >> "$GITHUB_OUTPUT"
            echo "ref=$DEFAULT_BRANCH" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          bot_login="$(gh api user --jq .login)"
          gh api "repos/$GH_REPO/pulls/$NUMBER" > "$RUNNER_TEMP/tidewave-pr.json"
          if ! jq -e --arg bot "$bot_login" --arg repo "$GH_REPO" '
            .state == "open" and .user.login == $bot and
            .head.repo.full_name == $repo and
            (.head.ref | startswith("bot/tidewave-"))
          ' "$RUNNER_TEMP/tidewave-pr.json" > /dev/null; then
            echo "Only open bot PRs on this repository's bot/tidewave- branches are supported"
            exit 1
          fi
          echo "kind=pr" >> "$GITHUB_OUTPUT"
          jq -r '"ref=" + .head.sha, "branch=" + .head.ref' \
            "$RUNNER_TEMP/tidewave-pr.json" >> "$GITHUB_OUTPUT"

      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          fetch-depth: 1
          persist-credentials: false
          ref: ${{ steps.task.outputs.ref }}

      - name: Record base commit
        id: base
        run: |
          echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
          printf '/tmp/\n' >> .git/info/exclude

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19"
          otp-version: "28"

      - name: Cache deps and build
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-dev-${{ hashFiles('mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-dev-

      - name: Set up the app
        run: mix setup

      # Tidewave is a dev-only dependency, so the server runs in the dev environment
      # The loop restarts the server whenever it exits, so the agent can restart it
      - name: Start the app
        run: |
          mkdir -p tmp
          (while true; do
            mix phx.server || echo "The app exited with status $?"
            echo "Restarting the app"
            sleep 1
          done) > tmp/app.log 2>&1 &

      - name: Connect Tidewave
        id: tidewave
        uses: tidewave-ai/connect-action@v1
        with:
          app_url: http://localhost:4000
          connect_key: ${{ secrets.TIDEWAVE_CONNECT_KEY }}

      - name: Prepare Codex prompt
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
          KIND: ${{ steps.task.outputs.kind }}
          REQUEST: >-
            ${{ github.event.comment.body || format('{0}: {1}', github.event.issue.title, github.event.issue.body || '') }}
        run: |
          gh "$KIND" view "$NUMBER" --json title,body,comments > tmp/tidewave-context.json
          if [ "$KIND" = pr ]; then
            gh pr diff "$NUMBER" > tmp/tidewave-pr.diff
          fi
          cat > tmp/codex-prompt.md <<'PROMPT'
          Read tmp/tidewave-context.json for the issue or pull request context.
          For a pull request, also read tmp/tidewave-pr.diff and the conversation,
          including your earlier replies, before making further changes.
          Follow the request below and summarize your changes and verification in
          your final answer. A later workflow step posts that answer to GitHub.

          The app is running at http://localhost:4000 with Tidewave, in the dev environment. Use the Tidewave MCP tools to evaluate code in the app and to verify your changes in the browser. It reloads code changes automatically, so do not start another server with mix phx.server. The server log is in tmp/app.log. Run mix precommit before you finish and fix any issues it reports.

          If you add a migration, run mix ecto.migrate. The app does not need a restart for this.

          If you change config files or add dependencies, restart the app:
          1. Run mix do deps.get + compile and fix any errors.
          2. Call System.stop() with the Tidewave project_eval tool. The workflow starts the app again automatically.
          3. The Tidewave tools are unavailable until the app is back up, which can take a few seconds. Wait and retry. If the app does not come back, check tmp/app.log.

          Only change code when the request asks you to implement or fix something.
          Leave your edits in the working tree: do not commit, create branches, push,
          or open a pull request. Do not change files under .github/.
          If you change code, write a short pull request title on one line in
          tmp/tidewave/pr-title.txt. Your final answer will be the pull request body
          for a new PR, or a comment on an existing PR. Explain the changes and how
          you verified them. The workflow updates the existing branch for bot PRs.

          Save screenshots and recordings under tmp/tidewave/. In your final answer, reference
          each file by its path, such as ![The settings page](tmp/tidewave/screenshots/settings.png).
          The workflow uploads the files and replaces these references with attachment URLs.
          To embed a video as a player, put its reference, such as ![](tmp/tidewave/recordings/flow.webm),
          alone in its own paragraph. Do not post the answer or upload the media yourself.
          PROMPT
          printf '\nRequest:\n%s\n' "$REQUEST" >> tmp/codex-prompt.md

      - name: Configure Codex
        env:
          CODEX_CONFIG_DIR: ${{ runner.temp }}/tidewave-codex
        run: |
          mkdir -p "$CODEX_CONFIG_DIR"
          cat > "$CODEX_CONFIG_DIR/config.toml" <<'CONFIG'
          [mcp_servers.tidewave]
          url = "${{ steps.tidewave.outputs.mcp_url }}"
          required = true
          default_tools_approval_mode = "approve"

          [permissions.tidewave]
          extends = ":workspace"

          [permissions.tidewave.network]
          enabled = true
          CONFIG

      - name: Run Codex
        id: codex
        uses: openai/codex-action@v1
        with:
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
          prompt-file: tmp/codex-prompt.md
          output-file: tmp/codex-answer.md
          codex-home: ${{ runner.temp }}/tidewave-codex
          permission-profile: tidewave
          safety-strategy: drop-sudo

      - name: Collect changes
        id: changes
        env:
          BASE_SHA: ${{ steps.base.outputs.sha }}
        run: |
          set -euo pipefail
          bundle="$RUNNER_TEMP/tidewave-changes"
          mkdir -p "$bundle/tmp"
          git add --all -- .
          git diff --cached --binary "$BASE_SHA" > "$bundle/changes.patch"
          if [ ! -s "$bundle/changes.patch" ]; then
            exit 0
          fi
          test -s tmp/tidewave/pr-title.txt
          cp tmp/codex-answer.md "$bundle/body.md"
          cp -R tmp/tidewave "$bundle/tmp/"
          echo "present=true" >> "$GITHUB_OUTPUT"

      - name: Upload changes
        if: steps.changes.outputs.present == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: tidewave-changes
          path: ${{ runner.temp }}/tidewave-changes

      - name: Post Codex answer with media
        if: steps.changes.outputs.present != 'true'
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          GH_REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
          KIND: ${{ steps.task.outputs.kind }}
        run: |
          shopt -s nullglob globstar nocaseglob
          files=(tmp/tidewave/**/*.{png,jpg,jpeg,gif,webp,webm,mp4,mov})
          args=(--body-file tmp/codex-answer.md)
          for f in "${files[@]}"; do args+=(--attach "$f"); done

          gh "$KIND" comment "$NUMBER" "${args[@]}"

      - name: Upload app log
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: app-log
          path: tmp/app.log
          if-no-files-found: ignore

  publish:
    needs: codex
    if: needs.codex.outputs.changes == 'true'
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          ref: ${{ needs.codex.outputs.base_sha }}

      - name: Download changes
        uses: actions/download-artifact@v4
        with:
          name: tidewave-changes
          path: ${{ runner.temp }}/tidewave-changes

      - name: Commit and push changes
        id: push
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          TARGET_BRANCH: ${{ needs.codex.outputs.branch }}
        run: |
          set -euo pipefail
          bundle="$RUNNER_TEMP/tidewave-changes"
          git apply --index "$bundle/changes.patch"
          if ! git diff --cached --quiet -- .github; then
            echo "Changes to .github/ are not allowed in this workflow"
            exit 1
          fi
          read -r bot_id bot_login < <(gh api user --jq '[.id, .login] | @tsv')
          title="$(head -n 1 "$bundle/tmp/tidewave/pr-title.txt")"
          branch="${TARGET_BRANCH:-bot/tidewave-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}}"
          git switch -c "$branch"
          git -c core.hooksPath=/dev/null \
            -c user.name="$bot_login" \
            -c user.email="${bot_id}+${bot_login}@users.noreply.github.com" \
            commit -m "$title"
          git push origin "HEAD:refs/heads/$branch"
          echo "branch=$branch" >> "$GITHUB_OUTPUT"

      - name: Publish result as the bot
        working-directory: ${{ runner.temp }}/tidewave-changes
        env:
          GH_TOKEN: ${{ secrets.GH_COMMENT_TOKEN }}
          GH_REPO: ${{ github.repository }}
          BASE_REF: ${{ github.event.repository.default_branch }}
          BRANCH: ${{ steps.push.outputs.branch }}
          NUMBER: ${{ github.event.issue.number }}
          KIND: ${{ needs.codex.outputs.kind }}
        run: |
          set -euo pipefail
          title="$(head -n 1 tmp/tidewave/pr-title.txt)"
          shopt -s nullglob globstar nocaseglob
          files=(tmp/tidewave/**/*.{png,jpg,jpeg,gif,webp,webm,mp4,mov})
          attachments=()
          for f in "${files[@]}"; do attachments+=(--attach "$f"); done
          if [ "$KIND" = pr ]; then
            gh pr comment "$NUMBER" --body-file body.md "${attachments[@]}"
          else
            printf '\n\nRefs #%s\n' "$NUMBER" >> body.md
            url="$(gh pr create --base "$BASE_REF" --head "$BRANCH" \
              --title "$title" --body-file body.md "${attachments[@]}")"
            gh issue comment "$NUMBER" --body "I opened $url with the changes."
          fi
```

## Manual setup

Running Tidewave in CI breaks down into two steps:

1. Run your project in its regular development environment, with Tidewave installed and enabled.
2. Keep a browser session open on your app's `/tidewave/connect` page for the duration of the agent's work.

The agent then connects to the app's `/tidewave/mcp` endpoint and controls that browser session through Tidewave's tools. The examples above use [`tidewave-ai/connect-action`](https://github.com/tidewave-ai/connect-action) to automate this setup. You can adapt its implementation or follow the steps below for another CI system.

### Prepare the app and browser

Install your app's dependencies, start any services it needs, and run the development server in the background. For Phoenix, this is usually `mix setup` followed by `mix phx.server`. Wait until the app serves `/tidewave/connect` successfully before launching Connect.

For screenshots and recordings, use a **headed Chromium browser**, with `--auto-accept-this-tab-capture` to accept the tab capture prompt automatically. On Linux without a display, run it under [Xvfb](https://playwright.dev/docs/ci#running-headed). The Connect action also removes Playwright's `--disable-infobars` default argument for tab capture compatibility.

For example, install Playwright and Chromium in your CI environment:

```sh
npm install --no-save playwright
npx playwright install --with-deps chromium
```

### Authenticate and open Connect

Exchange your Tidewave API key for a Connect token by making a `POST` request to `https://tidewave.ai/api/connect-key-exchange`. Send the API key in the `Authorization: Bearer ...` header and a JSON body with `team_id` set to your app's configured team ID, or `null` for a personal subscription. The response contains a `token` field. This token is valid for one day and is revoked if you delete the API key. The exchange happens outside the browser, so the API key itself is never passed to the page.

Pass the token and vision mode setting in the Connect URL's fragment:

```text
http://localhost:4000/tidewave/connect#tidewave_auth_token=<encoded-token>&tidewave_enable_vision_mode=true
```

Connect reads these parameters on page load and immediately removes them from the address bar. The fragment is not sent to the HTTP server. Build it with `URLSearchParams` so the token is encoded correctly, and avoid printing the token or the full launch URL to CI logs. Changing only the fragment of an already loaded page does not apply new settings. Open a new page with the parameters to apply them again.

For example, save this launcher as `tmp/tidewave-connect.mjs`. Set `TIDEWAVE_CONNECT_KEY` from your CI secret, and optionally set `APP_URL` and `TIDEWAVE_TEAM_ID` to match your app:

```javascript
import { chromium } from "playwright";

function baseUrl(value) {
  const url = new URL(value);
  if (!url.pathname.endsWith("/")) url.pathname += "/";
  return url;
}

const appUrl = baseUrl(process.env.APP_URL ?? "http://localhost:4000");
const tidewaveUrl = "https://tidewave.ai";
const connectKey = process.env.TIDEWAVE_CONNECT_KEY;
if (!connectKey) throw new Error("TIDEWAVE_CONNECT_KEY is required");
// Do not let the browser process inherit the API key.
delete process.env.TIDEWAVE_CONNECT_KEY;

const response = await fetch(new URL("api/api-key-exchange", tidewaveUrl), {
  method: "POST",
  headers: {
    authorization: `Bearer ${connectKey}`,
    "content-type": "application/json",
  },
  body: JSON.stringify({ team_id: process.env.TIDEWAVE_TEAM_ID || null }),
});
const auth = await response.json().catch(() => null);
if (!response.ok || typeof auth?.token !== "string") {
  throw new Error(`Tidewave API key exchange failed (HTTP ${response.status})`);
}

const connectUrl = new URL("tidewave/connect", appUrl);
connectUrl.hash = new URLSearchParams({
  tidewave_auth_token: auth.token,
  tidewave_enable_vision_mode: "true",
}).toString();

const browser = await chromium.launch({
  headless: false,
  args: [
    "--auto-accept-this-tab-capture",
    "--window-position=0,0",
    // adjust as necessary
    "--window-size=1920,1080",
  ],
  ignoreDefaultArgs: ["--disable-infobars"],
});

try {
  const context = await browser.newContext({ viewport: null });
  const page = await context.newPage();
  await page.goto(connectUrl.toString());
  await page.waitForSelector('html[data-tidewave-connect="ready"]', {
    state: "attached",
    timeout: 300_000,
  });
  console.log(`Tidewave Connect is ready; MCP URL: ${new URL("tidewave/mcp", appUrl)}`);

  await new Promise((resolve) => {
    process.once("SIGINT", resolve);
    process.once("SIGTERM", resolve);
    browser.once("disconnected", resolve);
  });
} catch {
  // Navigation errors can include the launch URL, which contains the token.
  console.error("Tidewave Connect failed to become ready; check the app and browser.");
  process.exitCode = 1;
} finally {
  await browser.close();
}
```

On Linux without a display, start the launcher under Xvfb and keep it running in the background:

```sh
mkdir -p tmp
xvfb-run -a -s "-screen 0 1920x1080x24" node tmp/tidewave-connect.mjs \
  > tmp/tidewave-connect.log 2>&1 &
```

If your CI image does not include `xvfb-run`, install the `xvfb` package first. With an existing display, run `node tmp/tidewave-connect.mjs` directly. Keep the launcher, browser, and display alive until the agent finishes, then stop them as part of your CI cleanup.

### Connect the agent

Wait for `html[data-tidewave-connect="ready"]` before starting the agent. The launcher prints its readiness message only after this marker appears, so your CI orchestration can wait for that message in `tmp/tidewave-connect.log`. If the launcher exits before becoming ready, fail the setup and check the app and browser logs.

Configure the agent's Tidewave MCP server with `http://localhost:4000/tidewave/mcp`, adjusting the host, port, or path prefix to match your app. The agent must be able to reach that endpoint, and the browser must be able to reach both the app and the Tidewave server.

Allow the agent to call Tidewave's tools without interactive approval, as shown in the Claude and Codex examples above. It can then evaluate code in the running app, navigate the browser, and capture screenshots or recordings through Tidewave. The browser session must remain open for those tools to work.
