# README

Adding a Map API to a GenServer or Module with Agent-held State.

Amlapio can be *use*-d to generate "wrapper" functions that call
Map functions on the state of a GenServer, or a module using
an Agent to hold its state.

Wrappers can be generated for the state itself or submaps of the state
(e.g. *buttons* in the examples below).

Wrappers for just a subset of Map functions can be specified using **funs**.

The wrapper functions can be named explicitly by supplying a **namer** function.

See my
[blog post](<http://ianrumford.github.io/elixir/map/api/genserver/module/agent/state/2016/09/13/amlapio.html>) for
some background.

## Installation

Add **amlapio** to your list of dependencies in <span class="underline">mix.exs</span>:

    def deps do
      [{:amlapio, "~> 0.2.0"}]
    end

## Agent Usage

The example below generates wrappers for the *buttons*, *menus* and
  *checkboxes* submaps of a Module using an Agent to hold its state. The
  names of the submap wrappers, by default, are of the form *submap\_function* e.g.
  *buttons\_pop*

It also generates three wrappers for the state itself by setting the
  submap names to nil (*agent: nil*). Also a
  **namer** (function) is given to name the state  wrappers *agent\_state\_get* ,
  *agent\_state\_put*, and *agent\_state\_pop*.

    defmodule ExampleAgent1 do
    
      # generate wrappers for three submaps
      use Amlapio, agent: [:buttons, :menus, :checkboxes]
    
      # generate *only* get, put and pop wrappers for the state itself and
      # use a namer function to name the wrappers "agent_state_get",
      # "agent_state_put" and "agent_state_pop"
      use Amlapio, agent: nil, funs: [:get, :put, :pop],
        namer: fn _map_name, fun_name ->
        ["agent_state_", to_string(fun_name)] |> Enum.join |> String.to_atom
      end
    
      # create the agent; note the default state is an empty map
      def start_link(state \\ %{}) do
        Agent.start_link(fn -> state end)
      end
    
    end

The state wrappers would be used as you'd expect and as shown in the test below:

    test "agent_state1" do
    
      buttons_state = %{1 => :button_back, 2 => :button_next, 3 => :button_exit}
      menus_state = %{menu_a: 1, menu_b: :two, menu_c: "tre"}
      checkboxes_state = %{checkbox_yesno: [:yes, :no], checkbox_bool: [true, false]}
      agent_state = %{buttons: buttons_state, menus: menus_state, checkboxes: checkboxes_state}
    
      # create the agent
      {:ok, agent} = ExampleAgent1.start_link(agent_state)
    
      # some usage examples
    
      assert buttons_state == agent |> ExampleAgent1.agent_state_get(:buttons)
    
      assert agent == agent |> ExampleAgent1.agent_state_put(:menus, 42)
      assert 42 == agent |> Agent.get(fn s -> s end) |> Map.get(:menus)
    
      assert {checkboxes_state, agent} == agent |> ExampleAgent1.agent_state_pop(:checkboxes)
      assert %{buttons: buttons_state, menus: 42} == agent |> Agent.get(fn s -> s end)
    
      assert 99 == agent |> ExampleAgent1.agent_state_get(:some_other_key, 99)
    
    end

Similarly the submap wrappers as demonstrated in the test below:

    test "agent_submap1" do
    
      buttons_state = %{1 => :button_back, 2 => :button_next, 3 => :button_exit}
      menus_state = %{menu_a: 1, menu_b: :two, menu_c: "tre"}
      checkboxes_state = %{checkbox_yesno: [:yes, :no], checkbox_bool: [true, false]}
      agent_state = %{buttons: buttons_state, 
                      menus: menus_state, checkboxes: checkboxes_state}
    
      # create the agent
      {:ok, agent} = ExampleAgent1.start_link(agent_state)
    
      # some usage examples
    
      assert :button_back == agent |> ExampleAgent1.buttons_get(1)
      assert :button_default == 
        agent |> ExampleAgent1.buttons_get(99, :button_default)
    
      assert agent == agent |> ExampleAgent1.menus_put(:menu_d, 42)
      assert menus_state |> Map.put(:menu_d, 42) == agent |> ExampleAgent1.agent_state_get(:menus)
    
      assert {[:yes, :no], agent} == 
        agent |> ExampleAgent1.checkboxes_pop(:checkbox_yesno)
    
    end

## GenServer Usage

Creating wrappers for a GenServer's state is very similar. However,
each wrapper has two "parts": an *api* function and a *handle\_call* function.

The *api* wrapper for e.g. \`buttons\_get/3\` looks like:

    # api wrapper for buttons_get
    def buttons_get(pid, button_name, button_default \\ nil) do
     GenServer.call(pid, {:buttons_get, button_name, button_default})
    end

... while the matching *handle\_call* looks like:

    def handle_call({:buttons_get, button_name, button_default}, _fromref, state) do
      value = state |> Map.get(:buttons, %{}) |> Map.get(button_name, button_default)
      {:reply, value, state}
    end

To prevent compiler warnings all of the *handle\_call* functions for
  a GenServer must be grouped together in the source. So there are
  two *uses* to define the wrappers: one for the *apis* and one for the *handle\_calls*

As for an agent, the example below generates wrappers for the *buttons*, *menus* and
  *checkboxes* submaps of the GenServer's state. 

In a minor difference to the agent example, the example generate four
 wrappers for the state itself and uses a
  **namer** (function) to name them *state\_get*, *state\_put*, *state\_pop* and *state\_take*.

    defmodule ExampleGenServer1 do
    
      # its a genserver
      use GenServer
    
      # generate API wrappers for three submaps
      use Amlapio, genserver_api: [:buttons, :menus, :checkboxes]
    
      # generate *only* get, put, pop and take wrappers for the state itself and
      # use a namer function to name the wrappers "state_get",
      # "state_put", "state_pop", and "state_take"
      use Amlapio, genserver_api: nil, funs: [:get, :put, :pop, :take],
        namer: fn _map_name, fun_name ->
        ["state_", to_string(fun_name)] |> Enum.join |> String.to_atom
      end
    
      # create the genserver; note the default state is an empty map
      def start_link(state \\ %{}) do
        GenServer.start_link(__MODULE__, state)
      end
    
      # << more functions>>
    
      # handle_calls start here
    
      # generate the handle_call functions for three submaps' wrappers
      use Amlapio, genserver_handle_call: [:buttons, :menus, :checkboxes]
    
      # generate the handle_call functions for the state wrappers.
      use Amlapio, genserver_handle_call: nil, funs: [:get, :put, :pop, :take],
        namer: fn _map_name, fun_name ->
        ["state_", to_string(fun_name)] |> Enum.join |> String.to_atom
      end
    
    end

Some examples of the state wrappers:

    test "genserver_state1" do
    
      buttons_state = %{1 => :button_back, 2 => :button_next, 3 => :button_exit}
      menus_state = %{menu_a: 1, menu_b: :two, menu_c: "tre"}
      checkboxes_state = %{checkbox_yesno: [:yes, :no], checkbox_bool: [true, false]}
      genserver_state = %{buttons: buttons_state, menus: menus_state, checkboxes: checkboxes_state}
    
      # create the genserver
      {:ok, genserver} = ExampleGenServer1.start_link(genserver_state)
    
      # some examples
    
      assert buttons_state == genserver |> ExampleGenServer1.state_get(:buttons)
    
      assert genserver == genserver |> ExampleGenServer1.state_put(:menus, 42)
      assert 42 == genserver |> ExampleGenServer1.state_get(:menus)
    
      assert {checkboxes_state, genserver} == genserver |> ExampleGenServer1.state_pop(:checkboxes)
      assert %{buttons: buttons_state, menus: 42} == 
        genserver |> ExampleGenServer1.state_take([:buttons, :menus, :checkboxes])
    
      assert 99 == genserver |> ExampleGenServer1.state_get(:some_other_key, 99)
    
    end

The submap wrappers are used in an identical way to the agent example as demonstrated
in the test below. Note these tests use the state functions.

    test "genserver_submap1" do
    
      buttons_state = %{1 => :button_back, 2 => :button_next, 3 => :button_exit}
      menus_state = %{menu_a: 1, menu_b: :two, menu_c: "tre"}
      checkboxes_state = %{checkbox_yesno: [:yes, :no], checkbox_bool: [true, false]}
      genserver_state = %{buttons: buttons_state, menus: menus_state, checkboxes: checkboxes_state}
    
      # create the genserver
      {:ok, genserver} = ExampleGenServer1.start_link(genserver_state)
    
      # some examples
    
      assert :button_back == genserver |> ExampleGenServer1.buttons_get(1)
      assert :button_default == genserver |> ExampleGenServer1.buttons_get(99, :button_default)
    
      assert genserver == genserver |> ExampleGenServer1.menus_put(:menu_d, 42)
      assert 42 == genserver |> ExampleGenServer1.state_get(:menus) |> Map.get(:menu_d)
    
      assert {[:yes, :no], genserver} == genserver |> ExampleGenServer1.checkboxes_pop(:checkbox_yesno)
      assert %{checkbox_bool: [true, false]} == genserver |> ExampleGenServer1.state_get(:checkboxes)
    
    end