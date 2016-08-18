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
    {:ok, context} = :erlzmq.context()
    {:ok, socket} = :erlzmq.socket(context, [:sub, active: true])
    emdr_relay = Config.get(:emdr_consumer, :relay)
    :ok = :erlzmq.connect(socket, emdr_relay)
    :ok = :erlzmq.setsockopt(socket, :subscribe, "")

    {:ok, socket}
  end

  @doc """
    Receive and parse messages, split them up and send them away via NSQ
  """
  def handle_info({:zmq, _socket, message, _more}, state) do
    message
    |> decompress
    |> process
    |> send_orders

    {:noreply, state}
  end

  @doc """
    Process message for submission to NSQ
  """
  def process(message) do
    message
    |> decode
    |> filter
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
  def filter(message) do
    case message["resultType"] do
      "orders" -> message
      _ -> []
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

  defp send_orders(orders) do
    # Push those orders to NSQ

    GenServer.cast({:global, :nsq_publisher}, {:orders, orders})
  end
end
