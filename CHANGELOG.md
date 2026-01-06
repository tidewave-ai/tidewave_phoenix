# Changelog

## v0.5.4 (2026-01-06)

* Bug fixes
  * Add `bandit` as an optional dependency with `>= v1.10.1` to address deflate issue in Claude Code

## v0.5.3 (2025-12-23)

* Bug fixes
  * Support flags and trailing spaces in CSP headers

## v0.5.2 (2025-11-22)

* Bug fixes
  * Fix logging with Unicode charlists

## v0.5.1 (2025-11-01)

* Enhancements
  * Add `Tidewave.clear_logs/0`
  * Add `/tidewave/config` endpoint for Tidewave App/CLI

* Bug fixes
  * Fix type of `get_logs`

## v0.5.0 (2025-09-08)

* Enhancements
  * Add `grep` option to `get_logs` in favor of `level`
  * Bundle `get_package_location` into `get_source_location`
  * Support team configuration

## 0.4.2 (2025-09-01)

* Enhancements
  * Raise if Tidewave is plugged after `Phoenix.LiveReloader`

## 0.4.1 (2025-08-22)

* Enhancements
  * Allow same host by default in `allowed_origins` (similar to Phoenix)
  * Support wildcards at the beginning of `allowed_origins`
  * Support optional ports and schemes in `allowed_origins`

## 0.4.0 (2025-08-19)

* Enhancements
  * Improve the experience if using outdated `phoenix_live_reload`
  * Improve the experience if Tidewave is plugged too late
  * Improve results for `search_package_docs` tool
  * Use new streamable HTTP MCP protocol

* Backwards incompatible changes
  * Previously deprecated file system tools have been removed

Important: if you previously configured your editor using the SSE transport instead of using a proxy, you likely need to reconfigure the MCP connection using "HTTP" or "Streamable HTTP" instead.

## 0.3.2 (2025-08-13)

* Bug fix
  * Fix shell endpoint on Windows

## 0.3.1 (2025-08-13)

* Enhancements
  * Improve error messages when peer or origin is not allowed

## 0.3.0 (2025-08-05)

* Enhancements
  * Return regular text in `get_ecto_schema`
  * Warn if `git` is not present
  * Support umbrella apps on Ecto tools
  * Support for upcoming Tidewave Web

* Deprecations
  * `?include_fs_tools=true` is deprecated as well as support for Claude Desktop in favor of any other editor or CLI that ships with built-in filesystem tools

## 0.2.0 (2025-07-11)

This release removes the `get_process_info` and `trace_process` tools. If you happened to use those a lot in the past, consider writing an AGENTS.md (or similar) instructions file to explain to your agent that it can do the same using `project_eval` and providing Elixir code. In Elixir 1.18.4+, there's also the `IEx.Helpers.process_info/1` function which does the same as `get_process_info`.

Furthermore, we also removed `package_search` because it turned out to not be that useful. `package_docs_search` was renamed to `search_package_docs`.

If you used the file system tools (which are only useful for Claude Desktop that does not provide file system integration by itself), we also removed the dedicated `grep_project_files` tool in favor of calling `git grep` (or similar) using `shell_eval`.

* Enhancements
  * Add `level` parameter to logs tool to specify a minimum log level
  * Add dedicated `get_docs` tool

* Removals
  * `get_process_info` and `trace_process` were removed in favor of `project_eval`
  * `grep_project_files` was removed in favor of `shell_eval`

## 0.1.10 (2025-06-24)

* Bug fixes
  * Fix ecto tools not working in umbrella projects
  * Fix exceptions in tools not being reported correctly

## 0.1.9 (2025-06-23)

* Enhancements
  * Log and abort start instead of crashing when trying to start Tidewave when Mix is not available
* Bug fixes
  * workaround Erlang bug OTP-19458 (GH-9222, PR-9349) causing the BEAM to crash on Windows when using Erlang >= 27.0 < 27.3

## 0.1.8 (2025-06-13)

* Enhancements
  * change `list_project_files` to always apply `.gitignore`, unless `include_ignored` is passed
* Bug fixes
  * fix line ending detection crashing when git returns multiple attributes

## 0.1.7 (2025-05-25)

* Enhancements
  * new `get_package_location` tool
  * removed `glob_project_files` tool by merging it into a new parameter for `list_project_files`
  * support configuring tools to exclude (or include) with the `tools` plug option (see README)
* Bug fixes
  * fix invalid parameter in `get_ecto_schemas` tool

## 0.1.6 (2025-05-08)

* Bug fixes
  * fix invalid schema definition for `get_source_location` tool

## 0.1.5 (2025-05-07)

* Enhancements
  * capture compile errors in `project_eval` tool
  * allow enabling debug logs with `config :tidewave, debug: true`
  * use a single `reference` instead of separate `module` and `function` parameters in `get_source_location` tool

## 0.1.4 (2025-05-02)

* Enhancements
  * ensure Hex dependency search tool only returns package name and version to
    prevent prompt injections from package descriptions
  * make `:inspect_opts` configurable and format charlists as lists by default

## 0.1.3 (2025-05-01)

* Enhancements
  * new Igniter installer for Tidewave
  * new documentation page for Neovim
* Bug fixes
  * allow tool calls without arguments
  * properly cleanup sessions when re-using processes (only applies to Bandit)

## 0.1.2 (2025-04-30)

* Enhancements
  * Perform code reloading on shell eval
  * Support new versions of the MCP standard
  * Refute to use `iex` on `shell_eval`
  * Improve `shell_eval` description
  * Allow ipv4 mapped ipv6 address for `127.0.0.1`

## 0.1.1 (2025-04-30)

* Enhancements
  * evaluate commands in a separate process with timeout
  * handle clients that are trying to establish a connection using the new Streamable transport by replying with 405 (Method not allowed)
    as documented in the MCP specification. (we will work on adding support for the new Streamable transport in the future!)
  * small improvements to the documentation and tool descriptions

## 0.1.0 (2025-04-29)

Initial release.
