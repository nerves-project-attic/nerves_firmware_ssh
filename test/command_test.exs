defmodule CommandTest do
  use ExUnit.Case
  alias Nerves.Firmware.SSH.Command

  test "that the fwup command parses" do
    assert Command.parse("fwup:100\nleftovers") == {:ok, [{:fwup, 100}], "leftovers"}
  end

  test "that the reboot command parses" do
    assert Command.parse("reboot\nleftovers") == {:ok, [:reboot], "leftovers"}
  end

  test "that multiple commands parse" do
    assert Command.parse("fwup:123,reboot\nleftovers") == {
             :ok,
             [{:fwup, 123}, :reboot],
             "leftovers"
           }
  end

  test "partial data is detected" do
    assert Command.parse("fwup") == {:error, :partial}
  end
end
