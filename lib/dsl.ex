defmodule Amlapio.DSL do

  @moduledoc false

  alias Amlapio.Snippets, as: AMLSnippets
  alias Amlapio.Utils, as: AMLUtils

  def map_wrap_dsl_verb(verb, snippet, map_wrap)

  def map_wrap_dsl_verb(:make, snippet, map_wrap) do

    snippet
    |> AMLSnippets.map_wrap_make_snippet(map_wrap)
    |> fn

        map_wrap when is_map(map_wrap) ->

        map_wrap

      ast when is_tuple(ast) ->

        ast

    end.()
    |> AMLUtils.map_wrap_fun_ast_save(map_wrap)

  end

  def map_wrap_dsl_verb(:push, snippet, map_wrap) do

    push_wrap = snippet
    |> map_wrap_dsl(map_wrap |> AMLUtils.map_wrap_push_wraps_reset)
    |> AMLUtils.map_wrap_snippet_wraps_reset

    map_wrap
    |> AMLUtils.map_wrap_push_wraps_push(push_wrap)

  end

  def map_wrap_dsl_verb(:pipe, snippet, map_wrap) do

    snippet
    |> map_wrap_dsl(map_wrap)
    # get all the individual map_wraps and extract their non-nil asts
    |> AMLUtils.map_wrap_snippet_wraps_get
    |> Enum.map(fn
      %{fun_ast: nil} -> nil
      %{fun_ast: fun_ast} = map_wrap ->

        #deblock
        fun_ast = case fun_ast do
                    {:__block__, _, [arg | []]} -> arg
                    fun_ast -> fun_ast
                  end

        # any explicit index?
        case map_wrap |> Map.get(:fun_ast_index) do
          x when is_integer(x) and x >= 0 -> {fun_ast, x}
          _ -> {fun_ast, 0}
        end

        _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    # need to pipe them together
    |> Enum.reduce(nil, fn
      {ast, _ndx}, nil -> ast
      {ast, 0}, pipe_ast ->
        #Macro.pipe(pipe_ast, ast, 0)
        quote do
          unquote(pipe_ast) |> unquote(ast)
        end
      {ast, ndx}, pipe_ast -> pipe_ast |> Macro.pipe(ast, ndx)
    end)
    |> AMLUtils.map_wrap_fun_ast_save(map_wrap)
    # houskeeping
    |> AMLUtils.map_wrap_snippet_wraps_reset

  end

  def map_wrap_dsl(dsl, map_wrap) do

    {map_wrap, snippet_wraps} = dsl
    # build a list of funs to call
    |> Enum.map(fn {verb, snippet} ->

      snippet_funs = snippet
      |> case do

           {funs_ante, snippet} ->

             [funs_ante,
              fn map_wrap -> map_wrap_dsl_verb(verb, snippet, map_wrap) end]

           {funs_ante, snippet, funs_post} ->

             [funs_ante,
              fn map_wrap -> map_wrap_dsl_verb(verb, snippet, map_wrap) end,
              funs_post]

           snippet ->

             fn map_wrap -> map_wrap_dsl_verb(verb, snippet, map_wrap) end

         end
         |> AMLUtils.list_wrap_flat_just
         |> Enum.reject(&is_nil/1)

      {verb, snippet_funs}

    end)
    |> Enum.reduce({map_wrap, []},
    fn {_verb, snippet_funs}, {map_wrap, snippet_wraps} ->

      map_wrap = snippet_funs
      |> Enum.reduce(map_wrap, fn fun, map_wrap -> fun.(map_wrap) end)

      {map_wrap, snippet_wraps ++ [map_wrap]}

    end)

    map_wrap
    |> AMLUtils.map_wrap_snippet_wraps_put(snippet_wraps)

  end

end

