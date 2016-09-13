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

defmodule ExampleAgent1Test do

  use ExUnit.Case

  require ExampleAgent1

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

end
