defmodule Amlapio do

  @moduledoc ~S"""
  Adding a `Map` API to a `GenServer`'s state or module using an
  `Agent` to hold its  state.

  Amlapio can be *use*-d to generate "wrapper" functions that call
  `Map` functions on the state itself, or submaps held in the state.

  All `Map` functions are supported except *new*.

  ## Options

  The options supported by Amlapio's *use* are:

  ### `funs` (optional)

  The (optional) names of one or more functions supported by `Map` e.g. *get*,
  *put*, *pop*, etc.

  If not supplied, wrappers are generated for **all** `Map` functions (except *new*).

  ### `namer` (optional)

  The `namer` is a function that is passed the *map_name* and *fun_name*
  (both `Atom`s) and is expected to return the name of the wrapper function (`Atom`).

  For state wrappers, *map_name* will be `nil`.

  ### `agent`

  `nil` or one or more function names to generate `Agent` wrappers for.

  `nil` means  generate wrappers for the state itself.

  The *use* below generates *get* and *put* wrappers for the
  **buttons** submap of an `Agent`

      use Amlapio, agent: [:buttons], funs: [:get, :put]

  (The example uses a utility function `new_agent/1` in the repo's
  tests to create the `Agent` process.)

  This example shows how to *get* the the value of **button1** key in the
  **buttons** submap of the `Agent`:

      iex> new_agent(%{buttons: %{button1: :button1_value}})
      ...> |> buttons_get(:button1)
      :button1_value

   *put* works as expected:

      iex> new_agent(%{buttons: %{}})
      ...> |> buttons_put(:button1, :button1_value)
      ...> |> Agent.get(fn s -> s end)
      %{buttons: %{button1: :button1_value}}

  The next *use* generates wrappers for all `Map` functions for
  the state of an `Agent` and names them e.g. *agent_update*

      use Amlapio, agent: nil,
      namer: fn _map_name, fun_name -> "agent_#{fun_name}" |> String.to_atom end

      iex> new_agent(%{name: :ian, city: :london})
      ...> |> agent_update(:country, :uk, &(&1))
      ...> |> Agent.get(fn s -> s end)
      %{name: :ian, city: :london, country: :uk}

      iex> new_agent(%{name: :ian, city: :london})
      ...> |> agent_has_key?(:country)
      false

  ### `behaviour_api` or `genserver_api`

  `behaviour_api` is an alias of `genserver_api`; either can be given.

  Wrappers for a behaviour like `GenServer` have two functions.
  One is the *client* API function and the other the *callback*
  function (e.g. `handle_call/3`).  The callback has to be defined
  together with all the other callbacks of the same name (else the
  compiler will warn).

  `behaviour_api` generates the *client* wrapper(s), here for the
  `GenServer` state and call them e.g. *gen_state_get*:

      use Amlapio, genserver_api: nil,
      namer: fn _map_name, fun_name -> "gen_state_#{fun_name}" |> String.to_atom end

  ### `behaviour_callback` or `genserver_handle_call`

  `behaviour_callback` is an alias of `genserver_handle_call`; either
  can be given.

  `behaviour_callback` generates the *callback* function for the
  *client* wrappers:

      use Amlapio, genserver_handle_call: nil,
      namer: fn _map_name, fun_name -> "gen_state_#{fun_name}" |> String.to_atom end

   With both *client* and *callback* generated, the wrappers can
   be called:

      iex> new_genserver(%{name: :ian, city: :london})
      ...> |> gen_state_update(:country, :uk, &(&1))
      ...> |> gen_state_get(:country)
      :uk

  ### `behaviour_module`

  The default `behaviour_module` is `GenServer` but other behaviours
  that support `call` and `handle_call` (e.g. [`GenMQTT`](https://hex.pm/packages/gen_mqtt)) can be given.

  Here is the `GenServer` example above, reworked for [`GenMQTT`]((https://hex.pm/packages/gen_mqtt))

      use Amlapio, behaviour_module: GenMQTT, behaviour_api: nil,
      namer: fn _map_name, fun_name -> "mqtt_#{fun_name}" |> String.to_atom end

      use Amlapio, behaviour_callback: nil,
      namer: fn _map_name, fun_name -> "mqtt_#{fun_name}" |> String.to_atom end

      iex> new_mqtt(%{host: "localhost"})
      ...> |> mqtt_put(:port, 1883)
      ...> |> mqtt_get(:port)
      1883

  ## Other Examples

  The README has similar examples as does the tests in the [repo](https://github.com/ianrumford/amlapio).

  """

  require Logger

  alias Amlapio.Utils, as: AMLUtils
  alias Amlapio.DSL, as: AMLDSL

  @type name :: atom
  @typedoc "The names of the Map functions to generate wrappers for"
  @type names :: nil | name | [name]

  @typedoc "The name of the state or submap; nil => state"
  @type map_name :: nil | atom

  @typedoc "The maybe quoted name of the module supplying the call function e.g. GenServer"
  @type maybe_quoted_behaviour_module :: module | Macro.t

  @typedoc "Maybe quoted namer fun"
  @type maybe_quoted_namer_fun :: Macro.t | ((map_name, name) -> name)

  @type use_option ::
  {:agent, names} |
  {:genserver_api, names} |
  {:genserver_handle_call, names} |
  {:behaviour_api, names} |
  {:behaviour_callback, names} |
  {:behaviour_function, name} |
  {:behaviour_module, maybe_quoted_behaviour_module} |
  {:namer, maybe_quoted_namer_fun}

  @typedoc "The supported options passed to the use call."
  @type use_options :: [use_option]

  @amlapio_opts_aliases [

    namer: nil,
    funs: nil,
    agent: nil,
    behaviour: :genserver,
    behaviour_module: nil,
    behaviour_api: :genserver_api,
    behaviour_callback: :genserver_handle_call,

  ]
  |> Stream.flat_map(fn {canon, aliases} ->

    aliases
    |> List.wrap
    |> List.flatten([canon])
    |> Stream.uniq
    |> Stream.reject(&is_nil/1)
    |> Enum.map(fn alias -> {alias, canon} end)

  end)
  |> Enum.into(%{})

  @amlapio_function_map_types_all [:agent, :behaviour, :behaviour_api, :behaviour_callback]
  @amlapio_function_map_types_allowed [:agent, :behaviour_api, :behaviour_callback]

  # create a map of the function names v Keyword list of name v arity
  @amlapio_functions_names_v_arities :functions
  |> Map.__info__
  # group the functions by name
  |> Enum.group_by(fn {name, _arity} -> name end)
  # drop unwanted keys
  |> Map.drop([:new])

  # hard coded list of all Map's mutator and popper functions
  @amlapio_functions_names_mutators [:delete, :drop, :merge, :put, :put_new, :put_new_lazy, :update, :update!]
  @amlapio_functions_names_poppers [:get_and_update!, :get_and_update, :pop, :pop_lazy]

  # create the accessor list by "subtracting" the others from the full list of functions
  @amlapio_functions_names_accessors @amlapio_functions_names_v_arities
  # get the names of all the functions
  |> Map.keys
  # subtract the mutators and poppers
  |> Kernel.--(@amlapio_functions_names_mutators ++ @amlapio_functions_names_poppers)

  # create a map of names v type i.e accessor or mutator
  @amlapio_functions_names_accessors_v_type @amlapio_functions_names_accessors
  |> Enum.map(fn name -> {name, :accessor} end)

  @amlapio_functions_names_mutators_v_type @amlapio_functions_names_mutators
  |> Enum.map(fn name -> {name, :mutator} end)

  @amlapio_functions_names_poppers_v_type @amlapio_functions_names_poppers
  |> Enum.map(fn name -> {name, :popper} end)

  # create a map with all functions
  @amlapio_functions_names_v_types [
    @amlapio_functions_names_accessors_v_type,
    @amlapio_functions_names_mutators_v_type,
    @amlapio_functions_names_poppers_v_type]
    |> Enum.reduce(fn l, s -> s ++ l end)
    |> Enum.into(%{})

  defp normalise_value_maybe_ast(value, opts \\ [])

  defp normalise_value_maybe_ast({:@, _, [{attr_name, _, _}]}, opts) do

    module = opts |> Keyword.fetch!(:module)

    Module.get_attribute(module, attr_name)

  end

  defp normalise_value_maybe_ast({_, _, _} = value, _opts) do
    case value |> Macro.validate do
      :ok -> value |> Code.eval_quoted([], __ENV__) |> elem(0)
      _ -> value
    end
  end

  # default
  defp normalise_value_maybe_ast(value, _opts) do
    value
  end

  defp select_map_funs_v_types(opts) do

    # only a subset of Map's functions wanted?
    case opts |> Keyword.has_key?(:funs) do

      # only some funs wanted
      true ->

        fun_names = opts |> Keyword.fetch!(:funs) |> List.wrap

        # ensure all supplied function names valid
        true = fun_names
        |> Enum.all?(fn fun_name -> Map.has_key?(@amlapio_functions_names_v_types, fun_name) end)

        # select the wanted function
        @amlapio_functions_names_v_types |> Map.take(fun_names)

        # all funs wanted
        false -> @amlapio_functions_names_v_types

    end

  end

  defp resolve_map_types(opts) do

    map_types = opts |> Keyword.take(@amlapio_function_map_types_all)

    # need to map behaviour to behaviour_callback and behaviour_api?
    map_types = case map_types |> Keyword.has_key?(:behaviour) do

                  true ->

                    genserver_types = map_types |> Keyword.fetch!(:behaviour)

                    [behaviour_callback: genserver_types,
                     behaviour_api: genserver_types]
                     |> Keyword.merge(map_types)
                     |> Keyword.delete(:behaviour)

                  _ -> map_types

                end

    # only one expected
    case map_types |> length do

      1 -> :ok

      _ ->

        raise ArgumentError, message: "found multiple map types #{inspect map_types} but one of #{inspect @amlapio_function_map_types_all} expected"

    end

    # if target is genserver, map it to the api and handlke call options
    map_types
    |> case do
         [:genserver] -> [:behaviour_callback, :behaviour_api]
         x -> x
       end

    opts
    |> Keyword.drop(@amlapio_function_map_types_all)
    |> Keyword.merge(map_types)

  end

  @doc false
  def process_opts(opts \\ []) do

    # get the fun_names_v_type
    fun_names_v_types = opts |> select_map_funs_v_types

    # was a function namer given? default if not.
    fun_namer =
      case opts |> Keyword.has_key?(:namer) do
        true -> opts |> Keyword.get(:namer) |> normalise_value_maybe_ast
        _ -> &AMLUtils.create_map_fun_name/2
      end

    true = is_function(fun_namer)

    # a behaviour module??
    behaviour_module =
      case opts |> Keyword.has_key?(:behaviour_module) do
        true ->  opts |> Keyword.get(:behaviour_module) |> normalise_value_maybe_ast
        _ -> GenServer
      end

    map_spec_defaults = %{behaviour_module: behaviour_module}

    opts = opts |> resolve_map_types

    @amlapio_function_map_types_allowed
    |> Enum.flat_map(fn map_type ->

      case opts |> Keyword.has_key?(map_type) do

        true ->

          case opts |> Keyword.get(map_type) do

            # if the key is nil it means create apis for state
            x when is_nil(x) ->

              [%{map_type: map_type, map_name: nil}]

            # submaps
            x ->

              x
              |> AMLUtils.list_wrap_flat_just
              |> Enum.map(fn map_name -> %{map_type: map_type, map_name: map_name} end)

          end

          _ -> []

      end
      # for each map spec, enumerate the fun names and types
      |> Enum.flat_map(fn %{map_name: map_name} = map_spec ->

        fun_names_v_types
        |> Enum.flat_map(fn {map_fun_name, fun_type} ->
          @amlapio_functions_names_v_arities
          |> Map.fetch!(map_fun_name)
          |> Enum.map(fn {_map_fun_name, fun_arity} ->
            # create the name of the wrapper fun e.g. buttons_update!
            fun_name = fun_namer.(map_name, map_fun_name)
            map_spec
            |> Map.merge(%{map_fun: map_fun_name,
                          fun_name: fun_name,
                          fun_type: fun_type,
                          fun_arity: fun_arity})

          end)
        end)
      end)

    end)
    # add defaults
    |> Enum.map(fn map_spec -> Map.merge(map_spec_defaults, map_spec) end)
    |> Enum.map(fn map_wrap -> [make: :make_fun] |> AMLDSL.map_wrap_dsl(map_wrap) end)
    |> Enum.map(fn
      %{fun_ast: fun_ast} -> fun_ast
      _ -> nil
    end)
    |> AMLUtils.list_wrap_flat_just

  end

  defp process_opts_normalise_kv(module, key, value)

  defp process_opts_normalise_kv(module, key, {:@, _, [{attr_name, _, _}]}) do
      ##defp process_opts_normalise_kv(module, key, {:'@', _, _} = value) do

    Module.get_attribute(module, attr_name)

    # module.__info__(:attributes)

    {key, Module.get_attribute(module, attr_name)}

  end

  defp process_opts_normalise_kv(_module, key, {_, _, _} = value) do
    {key, value |> normalise_value_maybe_ast}
  end

  # default
  defp process_opts_normalise_kv(_module, key, value) do
    {key, value}
  end

  defp process_opts_normalise_k!(key) do
    case @amlapio_opts_aliases |> Map.has_key?(key) do

      true ->  @amlapio_opts_aliases |> Map.fetch!(key)

      _ ->

        message = "Amlapio: unknown option #{inspect key}"
        Logger.error message
        raise ArgumentError, message

    end
  end

  @doc false
  def process_opts_normalise(module, opts \\ []) do

    opts
    # normalise the keys - could fail and raise exception
    |> Enum.map(fn {k,v} -> {k |> process_opts_normalise_k!, v} end)
    |> Enum.map(fn {key, value} ->

      process_opts_normalise_kv(module, key, value)

    end)

  end

  @doc ~S"""
  See above for the supported options to the `use` call.
  """
  @spec __using__(use_options) :: [Macro.t]
  defmacro __using__(opts) do

    __CALLER__.module
    |> process_opts_normalise(opts)
    |> __MODULE__.process_opts

  end

end

