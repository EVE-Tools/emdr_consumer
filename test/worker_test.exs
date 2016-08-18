defmodule WorkerTest do
  use ExUnit.Case, async: true

  alias EMDRConsumer.Worker

  doctest Worker

  setup do
    # Load EMDR message fixtures into context
    {:ok, message_json} = File.read("test/fixtures/order_message.json")
    {:ok, empty_message_json} = File.read("test/fixtures/empty_order_message.json")
    {:ok, history_json} = File.read("test/fixtures/history_message.json")

    {:ok, message_json:       message_json,
          empty_message_json: empty_message_json,
          history_json:       history_json}
  end

  test "decoding json works properly", context do
    result = Worker.decode(context[:message_json])
    assert result["generator"]["name"] == "Yapeal"
  end

  test "history messages get filtered", context do
    result = Worker.filter(context[:history_json] |> Worker.decode)
    assert result == []
  end

  test "order messages do not get filtered", context do
    result = Worker.filter(context[:message_json] |> Worker.decode)
    assert result != []
  end

  test "order's attributes get mapped properly", context do
    result = Worker.convert_uudif_to_orders(context[:message_json] |> Worker.decode)
    assert hd(result)["regionID"] == 10000065
  end

  test "nested atrributes are being mapped, too", context do
    result = Worker.convert_uudif_to_orders(context[:message_json] |> Worker.decode)
    assert hd(hd(result)["orders"])["price"] == 8999
  end

  test "rowsets get converted to JSON properly", context do
    result = context[:message_json]
    |> Worker.process
    |> Enum.map(&(&1 |> :jiffy.decode([:return_maps])))

    assert hd(result)["regionID"] == 10000065
  end

  test "empty rowsets are contained in output", context do
    result = context[:empty_message_json]
    |> Worker.process
    |> Enum.count

    assert result == 1
  end

  test "empty rowsets are contained in output, even if there are other rowsets", context do
    result = context[:message_json]
    |> Worker.process
    |> Enum.count

    assert result == 3
  end

  test "empty rowsets do not contain orders", context do
    result = context[:empty_message_json]
    |> Worker.process
    |> Enum.map(&(&1 |> :jiffy.decode([:return_maps])))

    assert hd(result)["orders"] == []
  end

  test "pipeline works when passing a history message", context do
    result = context[:history_json]
    |> Worker.process

    assert result == []
  end
end
