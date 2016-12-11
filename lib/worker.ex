defmodule EMDRConsumer.Worker do
  use GenServer

  @doc """
    Wrap start_link.
  """
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  @doc """
    Initialize server and open ZeroMQ socket to relay for receiving data from
    EMDR.
  """
  def init(_params) do
    emdr_relay = Config.get(:emdr_consumer, :relay)
    regex_name = Regex.compile!(Config.get(:emdr_consumer, :regex_name))
    regex_version = Regex.compile!(Config.get(:emdr_consumer, :regex_version))

    {:ok, context} = :erlzmq.context()
    {:ok, socket} = :erlzmq.socket(context, [:sub, active: true])
    :ok = :erlzmq.connect(socket, emdr_relay)
    :ok = :erlzmq.setsockopt(socket, :subscribe, "")

    {:ok, %{socket: socket, regex_name: regex_name, regex_version: regex_version}}
  end

  @doc """
    Receive and parse messages, split them up and send them away via NSQ.
  """
  def handle_info({:zmq, _socket, message, _more}, state) do
    message
    |> decompress
    |> process(state)
    |> send_orders

    {:noreply, state}
  end

  @doc """
    Process message for submission to NSQ
  """
  def process(message, state) do
    message
    |> decode
    |> filter(state)
    |> convert_uudif_to_orders
    |> convert_rowsets_to_json
  end

  defp decompress(message) do
    # Messages from EMDR are compressed, so decompress message first

    message
    |> :zlib.uncompress
  end

  @doc """
    Decode message's JSON into map
  """
  def decode(message) do
    message
    |> :jiffy.decode([:return_maps])
  end

  @doc """
    Only process "order" messages for now
    TODO: handle history messages, too
  """
  def filter(message, state) do
    message
    |> filter_orders
    |> filter_name(state)
    |> filter_version(state)
  end

  @doc """
    Filter messages which are not orders
  """
  def filter_orders(message) do
    case message["resultType"] do
      "orders" -> message
      _ -> []
    end
  end

  @doc """
    Filter messages by generator's name
  """
  def filter_name([], _state), do: []
  def filter_name(message, state) do
    case Regex.match?(state.regex_name, message["generator"]["name"]) do
      true -> message
      false -> []
    end
  end

  @doc """
    Filter messages by generator's version
  """
  def filter_version([], _state), do: []
  def filter_version(message, state) do
    case Regex.match?(state.regex_version, message["generator"]["version"]) do
      true -> message
      false -> []
    end
  end

  @doc """
    If message got filtered, pass empty list
  """
  def convert_uudif_to_orders([]), do: []

  @doc """
    Return list of rowsets from the message with mapped attributes instead
    of arrays as defined in UUDIF.
    See: http://dev.eve-central.com/unifieduploader/start
  """
  def convert_uudif_to_orders(message) do
    message
    |> Map.get("rowsets")
    |> Enum.map(&(map_orders(message["columns"], &1)))
    |> Enum.into([])
  end

  defp map_orders(columns, rowset) do
    # Map the order's attributes as defined by the columns key and put orders
    # into orders key. Drop the rows key, as we do not need it anymore.

    rows = rowset["rows"]
    rowset = Map.drop(rowset, ["rows"])
    orders = rows
    |> Enum.map(&(Enum.zip(columns, &1)
    |> Enum.into(%{})))

    Map.put(rowset, "orders", orders)
  end

  @doc """
    Convert list of rowsets to list of JSON encoded rowsets. Simple!
  """
  def convert_rowsets_to_json(rowsets) do
    rowsets |> Enum.map(&(:jiffy.encode(&1)))
  end

  defp send_orders([]), do: :ok

  defp send_orders(rowsets) do
    # Push those orders to NSQ
    GenServer.cast({:global, :nsq_publisher}, {:orders, rowsets})
  end
end
