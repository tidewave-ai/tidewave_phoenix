defmodule Tidewave.MagicBytes do
  @moduledoc false

  def type(<<0xFF, 0xD8, 0xFF, _::binary>>),
    do: :jpg

  def type(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: :png

  # WebM is a Matroska container:
  # EBML header: 1A 45 DF A3
  # "webm" DocType typically appears shortly after the header.
  def type(<<0x1A, 0x45, 0xDF, 0xA3, rest::binary>>) do
    if :binary.match(rest, "webm") != :nomatch do
      :webm
    else
      :unknown
    end
  end

  def type(_), do: :unknown
end
