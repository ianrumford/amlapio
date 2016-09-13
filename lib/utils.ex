defmodule Amlapio.Utils do

  @moduledoc false

  def list_wrap_flat_just(opts \\ []) do
    opts |> List.wrap |> List.flatten |> Enum.reject(&is_nil/1)
  end

  # this function creates the name (atom) of the wrapper
  # e.g. given the map 'buttons' and function 'update!'
  # it will return atom 'buttons_update!'

  def create_map_fun_name(map_name, fun_name) when is_nil(map_name) and is_atom(fun_name) do
    fun_name
  end

  def create_map_fun_name(map_name, fun_name) when is_atom(map_name) and is_atom(fun_name) do
    [to_string(map_name), "_", to_string(fun_name)] |> Enum.join |> String.to_atom
  end

  @map_functions_vars_map [:pid, :arg1, :arg2, :arg3, :state, :_from]
  |> Enum.map(fn name -> {name, name |> Macro.var(nil)} end)
  |> Enum.into(%{})

  @map_functions_signature_vars_list [:pid, :arg1, :arg2, :arg3]
  |> Enum.map(fn name -> @map_functions_vars_map |> Map.fetch!(name) end)

  def map_wrap_fun_signature_build(%{fun_name: fun_name,
                                     fun_arity: fun_arity,
                                     signature_type: :genserver_call,
                                     map_type: :genserver_api}) do

    fun_tuple_args = [fun_name] ++ Enum.slice(@map_functions_signature_vars_list, 1 .. (fun_arity - 1))

    [{:{}, [], fun_tuple_args}]

  end

  def map_wrap_fun_signature_build(%{fun_name: fun_name,
                                     fun_arity: fun_arity,
                                     signature_type: :def,
                                     map_type: :genserver_handle_call}) do

    fun_tuple_args = [fun_name] ++ Enum.slice(@map_functions_signature_vars_list, 1 .. (fun_arity - 1))

    fun_tuple = {:{}, [], fun_tuple_args}

    [fun_tuple |

      [:_from, :state]
      |> Enum.map(fn name -> @map_functions_vars_map |> Map.fetch!(name) end)
    ]

  end

  # default
  def map_wrap_fun_signature_build(%{fun_arity: fun_arity}) do
    @map_functions_signature_vars_list |> Enum.slice(1 .. (fun_arity - 1))
  end

  def map_wrap_vars_fetch!(names) when is_list(names) do
    names |> Enum.map(fn name -> name |> map_wrap_var_fetch! end)
  end

  def map_wrap_vars_fetch!(range) do

    cond do

      Range.range?(range) ->

        @map_functions_signature_vars_list |> Enum.slice(range)

    end

  end

  def map_wrap_var_fetch!(name) when is_atom(name) do
    @map_functions_vars_map |> Map.fetch!(name)
  end

  def map_wrap_fun_ast_get(map_wrap) do
    map_wrap |> Map.get(:fun_ast)
  end

  def map_wrap_fun_ast_put(map_wrap, ast) do
    map_wrap |> Map.put(:fun_ast, ast)
  end

  def map_wrap_fun_ast_save(new_map_wrap, map_wrap) when is_map(new_map_wrap)do

    map_wrap
    |> Map.merge(new_map_wrap)

  end

  def map_wrap_fun_ast_save(snippets, map_wrap) do

    fun_ast = snippets
    |> list_wrap_flat_just
    |> fn

      [] -> nil

      snippets ->

        quote do
          unquote_splicing(snippets)
        end

    end.()

    map_wrap
    |> map_wrap_fun_ast_put(fun_ast)

  end

  def map_wrap_push_wraps_get(map_wrap, default \\ []) do
    map_wrap |> Map.get(:push_wraps, default)
  end

  def map_wrap_push_wraps_put(map_wrap, value) do
    map_wrap |> Map.put(:push_wraps, value)
  end

  def map_wrap_push_wraps_push(map_wrap, value) do
    map_wraps = map_wrap
    |> map_wrap_push_wraps_get
    |> List.wrap
    |> Kernel.++(value |> List.wrap)

    map_wrap |> map_wrap_push_wraps_put(map_wraps)
  end

  def map_wrap_push_wraps_reset(map_wrap) do
    map_wrap |> Map.delete(:push_wraps)
  end

  def map_wrap_ast_index_set_1(map_wrap) do
    map_wrap |> Map.put(:fun_ast_index, 1)
  end

  def map_wrap_push_wraps_asts_reduce_recursive(map_wrap) do

    fun_ast = map_wrap
    |> map_wrap_push_wraps_get
    |> Enum.map(fn push_wrap ->

      fun_ast = push_wrap |> map_wrap_fun_ast_get

      push_asts = push_wrap
      |> map_wrap_push_wraps_get
      |> Enum.map(fn map_wrap ->
        map_wrap
        |> map_wrap_push_wraps_asts_reduce_recursive
        |> map_wrap_fun_ast_get
      end)

      List.wrap(push_asts) ++ List.wrap(fun_ast)

      #_ -> nil
    end)
    # flatten and add the "top level" fun ast
    |> List.flatten([map_wrap |> map_wrap_fun_ast_get])
    |> Enum.reject(&is_nil/1)
    |> fn

      [] -> nil

      asts ->

        quote do
          unquote_splicing(asts)
        end
    end.()

    map_wrap
    |> map_wrap_fun_ast_put(fun_ast)
    |> map_wrap_push_wraps_reset

  end

  def map_wrap_snippet_wraps_get(map_wrap, default \\ []) do
    map_wrap |> Map.get(:snippet_wraps, default)
  end

  def map_wrap_snippet_wraps_put(map_wrap, value) do
    map_wrap |> Map.put(:snippet_wraps, value)
  end

   def map_wrap_snippet_wraps_reset(map_wrap) do
    map_wrap |> Map.delete(:snippet_wraps)
  end

end
