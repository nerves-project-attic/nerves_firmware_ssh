defmodule CommandTest do
  use ExUnit.Case

  test "that the fwup command parses" do
    assert Sshdtest.Command.parse("FWUP\nleftovers") == {:ok, [:fwup], "leftovers"}
  end
  test "that the reboot command parses" do
    assert Sshdtest.Command.parse("REBOOT\nleftovers") == {:ok, [:reboot], "leftovers"}
  end

  test "that multiple commands parse" do
    assert Sshdtest.Command.parse("FWUP,REBOOT\nleftovers") == {:ok, [:fwup, :reboot], "leftovers"}
  end

  test "partial data is detected" do
    assert Sshdtest.Command.parse("FWUP") == {:error, :partial}
  end

end
