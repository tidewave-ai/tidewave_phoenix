defmodule SampleAppWeb.CoreComponents do
  @moduledoc false
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="confirm-modal">
        Are you sure?
      </.modal>
  """
  attr :id, :string, required: true, doc: "The unique identifier for the modal"
  attr :show, :boolean, default: false, doc: "Whether to show the modal"
  attr :on_cancel, JS, default: %JS{}, doc: "JS command to run when modal is cancelled"

  slot :inner_block, required: true, doc: "The modal content"

  def modal(assigns) do
    ~H"""
    <div id={@id} class="modal">
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button", doc: "The button type"
  attr :variant, :atom, default: :primary, doc: "The button variant: :primary, :secondary, :danger"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} disabled={@disabled} class={@class}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input field.
  """
  attr :field, Phoenix.HTML.FormField, required: true, doc: "The form field"
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil

  def input(assigns) do
    ~H"""
    <div>
      <label :if={@label}>{@label}</label>
      <input type={@type} name={@field.name} value={@field.value} placeholder={@placeholder} />
    </div>
    """
  end

  def header(assigns) do
    ~H"""
    <header>
      {render_slot(@inner_block)}
    </header>
    """
  end

  def form(assigns) do
    ~H"""
    <form>
      {render_slot(@inner_block)}
    </form>
    """
  end
end

defmodule SampleAppWeb.Components.UserTable do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Renders a table of users.
  """
  attr :users, :list, required: true, doc: "The list of users to display"
  attr :sortable, :boolean, default: true
  attr :class, :string, default: nil

  slot :action, doc: "Action buttons for each row"

  def table(assigns) do
    ~H"""
    <table class={@class}>
      <tbody>
        <tr :for={user <- @users}>
          <td>{user.name}</td>
          <td :if={@action != []}>
            {render_slot(@action, user)}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end
end

defmodule SampleAppWeb.ComponentWithoutAttrs do
  @moduledoc false
  use Phoenix.Component

  def simple(assigns) do
    ~H"""
    <div>Simple component</div>
    """
  end
end
