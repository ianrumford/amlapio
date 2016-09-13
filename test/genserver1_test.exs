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

defmodule ExampleGenServer1Test do

  use ExUnit.Case

  require ExampleGenServer1

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

end
