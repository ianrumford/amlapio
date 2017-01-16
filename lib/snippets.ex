defmodule Amlapio.Snippets do

  @moduledoc false

  alias Amlapio.Utils, as: AMLUtils
  alias Amlapio.DSL, as: AMLDSL

  def map_wrap_make_snippet(snippet, map_wrap)

  def map_wrap_make_snippet(:behaviour_call, map_wrap) do

    behaviour_module = map_wrap |> Map.get(:behaviour_module, GenServer)
    behaviour_function = map_wrap |> Map.get(:behaviour_function, :call)

    fun_signature = map_wrap
    |> Map.put(:signature_type, :behaviour_call)
    |> AMLUtils.map_wrap_fun_signature_build

    quote do
      #pid |> GenServer.call(unquote_splicing(fun_signature))
      pid |> unquote(behaviour_module).unquote(behaviour_function)(unquote_splicing(fun_signature))
    end

  end

  def map_wrap_make_snippet(:fun_def, %{map_type: :behaviour_callback,
                                        fun_ast: fun_ast} = map_wrap) do

    fun_signature = map_wrap
    |> Map.put(:signature_type, :def)
    |> AMLUtils.map_wrap_fun_signature_build

    quote do
      def handle_call(unquote_splicing(fun_signature)) do
        unquote(fun_ast)
      end
    end
  end

  def map_wrap_make_snippet(:fun_def, %{fun_name: fun_name,
                                        fun_ast: fun_ast} = map_wrap) do

    fun_signature = map_wrap |> AMLUtils.map_wrap_fun_signature_build

    quote do
      def unquote(fun_name)(pid, unquote_splicing(fun_signature)) do
        unquote(fun_ast)
      end
    end
  end

  def map_wrap_make_snippet(:fun_anon_state_call, %{fun_ast: fun_ast}) do
    quote do
      fn state -> unquote(fun_ast) end.()
    end
  end

  def map_wrap_make_snippet(:state_get, %{map_type: :behaviour_callback}) do
    quote do
      # start with the agent (pid) and get its state
      unquote(AMLUtils.map_wrap_var_fetch!(:state))
    end
  end

  def map_wrap_make_snippet(:state_get, %{map_type: :agent}) do
    quote do
      # start with the agent (pid) and get its state
      pid |> Agent.get(fn state -> state end)
    end
  end

  def map_wrap_make_snippet(:state_put, %{map_type: :agent}) do
    quote do
      # update the agent (pid) with new state
      :ok = pid |> Agent.update(fn _ -> unquote(AMLUtils.map_wrap_var_fetch!(:state)) end)
    end
  end

  def map_wrap_make_snippet(:state_put, %{map_type: :behaviour_callback}) do
    nil
  end

  def map_wrap_make_snippet(:put_submap, %{map_name: map_name}) do
    quote do
      # put the submap into the state.  still needs both state and value.
      Map.put(unquote(map_name), submap)
    end
  end

  def map_wrap_make_snippet(:submap_get, %{map_name: map_name})
  when is_nil(map_name) do
    nil
  end

  def map_wrap_make_snippet(:submap_get, %{map_name: map_name}) do
    quote do
      # get the submap (from the state) (default a new map)
      Map.get(unquote(map_name), %{})
    end
  end

  def map_wrap_make_snippet(:submap_put, %{map_name: map_name})
  when is_nil(map_name) do
    nil
  end

  def map_wrap_make_snippet(:submap_put, %{map_name: map_name}) do
    quote do
      # put the submap into the state.  still needs both state and value.
      Map.put(unquote(map_name))
    end
  end

  def map_wrap_make_snippet(:fun_apply, %{map_fun: map_fun} = map_wrap) do

    fun_signature = map_wrap |> AMLUtils.map_wrap_fun_signature_build

    quote do
      # apply the Map function with args
      Map.unquote(map_fun)(unquote_splicing(fun_signature))
    end
  end

  def map_wrap_make_snippet(:state, _) do
    quote do
      unquote(AMLUtils.map_wrap_var_fetch!(:state))
    end
  end

  def map_wrap_make_snippet(:assign_state, %{fun_ast: fun_ast}) do
    quote do
      ##state = unquote(fun_ast)
      unquote(AMLUtils.map_wrap_var_fetch!(:state)) = unquote(fun_ast)
    end
  end

  def map_wrap_make_snippet(:assign_value, %{fun_ast: fun_ast}) do
    quote do
      value = unquote(fun_ast)
    end
  end

  def map_wrap_make_snippet(:assign_value_state_tuple, %{fun_ast: fun_ast}) do
    quote do
      {value, unquote(AMLUtils.map_wrap_var_fetch!(:state))} = unquote(fun_ast)
    end
  end

  def map_wrap_make_snippet(:assign_value_state_or_submap_tuple, %{fun_ast: fun_ast}) do
    quote do
      {value, submap} = unquote(fun_ast)
    end
  end

  def map_wrap_make_snippet(:assign_value_submap_tuple, %{fun_ast: fun_ast}) do
    quote do
      {value, submap} = unquote(fun_ast)
    end
  end

  def map_wrap_make_snippet(:pid, _) do
    quote do
      pid
    end
  end

  def map_wrap_make_snippet(:result_value, %{map_type: :agent,
                                             fun_type: :popper}) do
    quote do
      # return the value and pid tuple
      {value, pid}
    end
  end

  def map_wrap_make_snippet(:result_value, %{map_type: :agent}) do
    quote do
      # return the pid
      pid
    end
  end

  def map_wrap_make_snippet(:result_value, %{map_type: :behaviour_callback,
                                             fun_type: :popper}) do
    quote do
      {:reply, {value, self()}, unquote(AMLUtils.map_wrap_var_fetch!(:state))}
    end
  end

  def map_wrap_make_snippet(:result_value, %{map_type: :behaviour_callback,
                                                      fun_type: :accessor}) do
    quote do
      {:reply, value, unquote(AMLUtils.map_wrap_var_fetch!(:state))}
    end
  end

  def map_wrap_make_snippet(:result_value, %{map_type: :behaviour_callback,
                                             fun_type: :mutator}) do
    quote do
      {:reply, self(), unquote(AMLUtils.map_wrap_var_fetch!(:state))}
    end
  end

  def map_wrap_make_snippet(:make_body, %{map_type: :behaviour_api} = map_wrap) do

    [push: [make: :behaviour_call]]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{map_type: :behaviour_api} = map_wrap) do

    [push: [make: :make_body],
     make: {&AMLUtils.map_wrap_push_wraps_asts_reduce_recursive/1, :fun_def}
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_body, %{fun_type: :accessor, map_name: nil} = map_wrap) do

    [pipe: [make: :state_get, make: :fun_apply]]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_body, %{fun_type: :accessor} = map_wrap) do

    [pipe: [make: :state_get, make: :submap_get, make: :fun_apply]]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{fun_type: :accessor,
                                         map_type: :behaviour_callback} = map_wrap) do

    [push: [make: :make_body, make: :assign_value],

     push: [make: :result_value],

     make: {&AMLUtils.map_wrap_push_wraps_asts_reduce_recursive/1, :fun_def}
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{fun_type: :accessor} = map_wrap) do

    [make: :make_body, make: :fun_def]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_body, %{fun_type: :mutator, map_name: nil} = map_wrap) do

    [push: [pipe: [pipe: [make: :state, make: :fun_apply]], make: :assign_state]]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_body, %{fun_type: :mutator} = map_wrap) do

    [push: [pipe: [make: :state,

                   pipe: [

                     pipe: [make: :state, make: :submap_get, make: :fun_apply],

                     make: {&AMLUtils.map_wrap_ast_index_set_1/1, :submap_put},

                   ]],

            make: :assign_state]
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{fun_type: :mutator,
                                         map_type: :behaviour_callback} = map_wrap) do

    [push: [make: :make_body],

    push: [make: :result_value],

    make: {&AMLUtils.map_wrap_push_wraps_asts_reduce_recursive/1, :fun_def}
   ]
   |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{fun_type: :mutator} = map_wrap) do

    [push: [make: :state_get, make: :assign_state],

     push: [make: :make_body],

     push: [make: :state_put],

     push: [make: :result_value],

     make: {&AMLUtils.map_wrap_push_wraps_asts_reduce_recursive/1, :fun_def}
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_body, %{fun_type: :popper, map_name: nil} = map_wrap) do

    [push: [pipe: [make: :state, make: :fun_apply], make: :assign_value_state_tuple]]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_body, %{fun_type: :popper} = map_wrap) do

    [push: [pipe: [make: :state, make: :submap_get, make: :fun_apply],
            make: :assign_value_submap_tuple],

     push: [pipe: [make: :state, make: :put_submap], make: :assign_state]
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{fun_type: :popper,
                                         map_type: :behaviour_callback} = map_wrap) do

    [push: [make: :make_body],

     push: [make: :result_value],

     make: {&AMLUtils.map_wrap_push_wraps_asts_reduce_recursive/1, :fun_def}
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

  def map_wrap_make_snippet(:make_fun, %{fun_type: :popper} = map_wrap) do

    [push: [make: :state_get, make: :assign_state],

     push: [make: :make_body],

     push: [make: :state_put],

     push: [make: :result_value],

     make: {&AMLUtils.map_wrap_push_wraps_asts_reduce_recursive/1, :fun_def}
    ]
    |> AMLDSL.map_wrap_dsl(map_wrap)

  end

end
