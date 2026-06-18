defmodule Tidewave.Socket do
  @moduledoc false
  use Phoenix.Socket, log: false

  channel("tidewave:browser", Tidewave.BrowserChannel)

  def connect(_params, socket) do
    if Tidewave.ControlPlane.enabled?() do
      {:ok, socket}
    else
      :error
    end
  end

  def id(_socket), do: nil
end
