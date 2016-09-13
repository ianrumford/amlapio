defmodule Amlapio do

  @moduledoc false

  alias Amlapio.Utils, as: AMLUtils
  alias Amlapio.DSL, as: AMLDSL

  @map_function_map_types_all [:agent, :genserver, :genserver_api, :genserver_handle_call]
  @map_function_map_types_allowed [:agent, :genserver_api, :genserver_handle_call]

  # create a map of the function names v Keyword list of name v arity
  @map_functions_names_v_arities :functions
  |> Map.__info__
  # group the functions by name
  |> Enum.group_by(fn {name, _arity} -> name end)
  # drop unwanted keys
  |> Map.drop([:new])

  # create a list of all Map's function names
  @map_functions_names_all @map_functions_names_v_arities |> Map.keys

  # a hard coded list of all Map's mutator and popper functions
  @map_functions_names_mutators [:delete, :drop, :merge, :put, :put_new, :put_new_lazy, :update, :update!]
  @map_functions_names_poppers [:get_and_update!, :get_and_update, :pop, :pop_lazy]

  # create the accessor list by "subtracting" the others from the full list of functions
  @map_functions_names_accessors @map_functions_names_v_arities
  # get the names of all the functions
  |> Map.keys
  # subtract the mutators and poppers
  |> Kernel.--(@map_functions_names_mutators ++ @map_functions_names_poppers)

  # create a map of names v type i.e accessor or mutator
  @map_functions_names_accessors_v_type @map_functions_names_accessors
  |> Enum.map(fn name -> {name, :accessor} end)

  @map_functions_names_mutators_v_type @map_functions_names_mutators
  |> Enum.map(fn name -> {name, :mutator} end)

  @map_functions_names_poppers_v_type @map_functions_names_poppers
  |> Enum.map(fn name -> {name, :popper} end)

  # create a map with all functions
  @map_functions_names_v_types [
    @map_functions_names_accessors_v_type,
    @map_functions_names_mutators_v_type,
    @map_functions_names_poppers_v_type]
    |> Enum.reduce(fn l, s -> s ++ l end)
    |> Enum.into(%{})

  defp select_map_funs_v_types(opts) do

    # only a subset of Map's functions wanted?
    case opts |> Keyword.has_key?(:funs) do

      # only some funs wanted
      true ->

        fun_names = opts |> Keyword.fetch!(:funs) |> List.wrap

        # ensure all supplied function names valid
        true = fun_names
        |> Enum.all?(fn fun_name -> Map.has_key?(@map_functions_names_v_types, fun_name) end)

        # select the wanted functions
        @map_functions_names_v_types |> Map.take(fun_names)

        # all funs wanted
        false -> @map_functions_names_v_types

    end

  end

  defp resolve_map_types(opts) do

    map_types = opts |> Keyword.take(@map_function_map_types_all)

    # need to map genserver to genserver_handle_call and genserver_api?
    map_types = case map_types |> Keyword.has_key?(:genserver) do

                  true ->

                    genserver_types = map_types |> Keyword.fetch!(:genserver)

                    [genserver_handle_call: genserver_types,
                     genserver_api: genserver_types]
                     |> Keyword.merge(map_types)
                     |> Keyword.delete(:genserver)

                  _ -> map_types

                end

    # only one expected
    case map_types |> length do

      1 -> :ok

      _ ->

        raise ArgumentError, message: "found multiple map types #{inspect map_types} but one of #{inspect @map_function_map_types_all} expected"

    end

    # if target is genserver, map it to the api and handlke call options
    map_types
    |> case do
         [:genserver] -> [:genserver_handle_call, :genserver_api]
         x -> x
       end

    opts
    |> Keyword.drop(@map_function_map_types_all)
    |> Keyword.merge(map_types)

  end

  @doc false
  def process_opts(opts \\ []) do

    # get the fun_names_v_type
    fun_names_v_types = opts |> select_map_funs_v_types

    # was a function namer given? default if not.
    fun_namer =
      case opts |> Keyword.has_key?(:namer) do

        true ->

        {fun, _} = opts
        |> Keyword.get(:namer)
        # its an ast and needs to be eval-ed!
        |> Code.eval_quoted([], __ENV__)

          fun

          #&create_map_fun_name/2

        _ -> &AMLUtils.create_map_fun_name/2
      end

    opts = opts |> resolve_map_types

    @map_function_map_types_allowed
    |> Enum.flat_map(fn map_type ->

      case opts |> Keyword.has_key?(map_type) do

        true ->

          case opts |> Keyword.get(map_type) do

            # if the key is nil it means create api for state
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
          @map_functions_names_v_arities
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
    |> Enum.map(fn map_wrap -> [make: :make_fun] |> AMLDSL.map_wrap_dsl(map_wrap) end)
    |> Enum.map(fn
      %{fun_ast: fun_ast} -> fun_ast
      _ -> nil
    end)
    |> AMLUtils.list_wrap_flat_just

  end

  defmacro __using__(opts) do

    # build the wrappers for each map
    opts |> __MODULE__.process_opts

    # TESTING
    #nil
  end

end
