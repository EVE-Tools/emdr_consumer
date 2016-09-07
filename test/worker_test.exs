defmodule WorkerTest do
  use ExUnit.Case, async: true

  alias EMDRConsumer.Worker

  doctest Worker

  setup do
    # Load EMDR message fixtures into context
    {:ok, message_json} = File.read("test/fixtures/order_message.json")
    {:ok, empty_message_json} = File.read("test/fixtures/empty_order_message.json")
    {:ok, history_json} = File.read("test/fixtures/history_message.json")

    # Compile regexes
    {:ok, regex_name_correct} = Regex.compile("Yapeal")
    {:ok, regex_name_wrong} = Regex.compile("EMDR")
    {:ok, regex_version_correct} = Regex.compile("11\.335\.1737")
    {:ok, regex_version_wrong} = Regex.compile("12\.335\.1737")

    correct_state = %{regex_name: regex_name_correct, regex_version: regex_version_correct}

    {:ok, message_json:          message_json,
          empty_message_json:    empty_message_json,
          history_json:          history_json,
          regex_name_correct:    regex_name_correct,
          regex_name_wrong:      regex_name_wrong,
          regex_version_correct: regex_version_correct,
          regex_version_wrong:   regex_version_wrong,
          correct_state:         correct_state}
  end

  test "decoding json works properly", context do
    result = Worker.decode(context[:message_json])
    assert result["generator"]["name"] == "Yapeal"
  end

  test "history messages get filtered", context do
    result = Worker.filter(context[:history_json] |> Worker.decode, context[:correct_state])
    assert result == []
  end

  test "order messages do not get filtered", context do
    result = Worker.filter(context[:message_json] |> Worker.decode, context[:correct_state])
    assert result != []
  end

  test "correct generator names and versions do not get filtered", context do
    state = %{
              regex_name:    context[:regex_name_correct],
              regex_version: context[:regex_version_correct]
            }
    result = Worker.filter(context[:message_json] |> Worker.decode, state)
    assert result != []
  end

  test "wrong generator names get filtered", context do
    state = %{
              regex_name:    context[:regex_name_wrong],
              regex_version: context[:regex_version_correct]
            }
    result = Worker.filter(context[:message_json] |> Worker.decode, state)
    assert result == []
  end

  test "wrong generator versions get filtered", context do
    state = %{
              regex_name:    context[:regex_name_correct],
              regex_version: context[:regex_version_wrong]
            }
    result = Worker.filter(context[:message_json] |> Worker.decode, state)
    assert result == []
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
    |> Worker.process(context[:correct_state])
    |> Enum.map(&(&1 |> :jiffy.decode([:return_maps])))

    assert hd(result)["regionID"] == 10000065
  end

  test "empty rowsets are contained in output", context do
    result = context[:empty_message_json]
    |> Worker.process(context[:correct_state])
    |> Enum.count

    assert result == 1
  end

  test "empty rowsets are contained in output, even if there are other rowsets", context do
    result = context[:message_json]
    |> Worker.process(context[:correct_state])
    |> Enum.count

    assert result == 3
  end

  test "empty rowsets do not contain orders", context do
    result = context[:empty_message_json]
    |> Worker.process(context[:correct_state])
    |> Enum.map(&(&1 |> :jiffy.decode([:return_maps])))

    assert hd(result)["orders"] == []
  end

  test "pipeline works when passing a history message", context do
    result = context[:history_json]
    |> Worker.process(context[:correct_state])

    assert result == []
  end
end
