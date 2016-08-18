defmodule EMDRConsumer.NSQPublisher do
  alias Config

  use GenServer

  @doc """
    Wrap start_link.
  """
  def start_link do
    GenServer.start_link(__MODULE__, [], name: {:global, :nsq_publisher})
  end

  @doc """
    Initialize server and open NSQ connection to backend message queue.
  """
  def init(_params) do
    nsqd = Config.get(:emdr_consumer, :nsqd)

    {:ok, producer} = NSQ.Producer.Supervisor.start_link("orders", %NSQ.Config{
      nsqds: [nsqd],
      deflate: true,
      deflate_level: 9,
    })

    {:ok, producer}
  end

  @doc """
    Publish messages to NSQ.
  """
  def handle_cast({:orders, orders}, producer) do
    NSQ.Producer.mpub(producer, orders)

    {:noreply, producer}
  end
end
