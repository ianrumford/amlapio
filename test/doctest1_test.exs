defmodule ExampleDoctestAgent1Test do

  use GenServer

  require Amlapio

  # generate wrappers for three submaps
  ##use Amlapio, agent: [:buttons, :menus, :checkboxes]
  use Amlapio, agent: [:buttons], funs: [:get, :put]

  use Amlapio, agent: nil,
    namer: fn _map_name, fun_name ->
    "agent_#{fun_name}" |> String.to_atom
  end

end

defmodule ExampleDoctestGenServer1Test do

  use GenServer
  require Amlapio

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  use Amlapio, genserver_api: nil,
    namer: fn _map_name, fun_name ->
    "gen_state_#{fun_name}" |> String.to_atom
  end

  use Amlapio, genserver_handle_call: nil,
    namer: fn _map_name, fun_name ->
    "gen_state_#{fun_name}" |> String.to_atom
  end

end

defmodule ExampleDoctestGenMQTT1Test do

  use GenMQTT
  require Amlapio

  def start_link(state) do
    GenMQTT.start_link(__MODULE__, state, [])
  end

  use Amlapio, behaviour_module: GenMQTT, behaviour_api: nil,
    namer: fn _map_name, fun_name ->
    "mqtt_#{fun_name}" |> String.to_atom
  end

  use Amlapio, behaviour_callback: nil,
    namer: fn _map_name, fun_name ->
    "mqtt_#{fun_name}" |> String.to_atom
  end

end

defmodule AmlapioDoctest1Test do

  use ExUnit.Case, async: true

  require ExampleDoctestAgent1Test
  import ExampleDoctestAgent1Test

  require ExampleDoctestGenServer1Test
  import ExampleDoctestGenServer1Test

  require ExampleDoctestGenMQTT1Test
  import ExampleDoctestGenMQTT1Test

  def new_agent(state) when is_map(state) do
    {:ok, pid} = Agent.start_link(fn -> state end)
    pid
  end

  def new_genserver(state) when is_map(state) do
    {:ok, pid} = ExampleDoctestGenServer1Test.start_link(state)
    pid
  end

  def new_mqtt(state) when is_map(state) do
    {:ok, pid} = ExampleDoctestGenMQTT1Test.start_link(state)
    pid
  end

  doctest Amlapio

end
