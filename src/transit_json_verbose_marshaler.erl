-module(transit_json_verbose_marshaler).
-behaviour(transit_marshaler).
-include_lib("transit_format.hrl").

-export([emit_null/2, emit_boolean/2, emit_int/2, emit_float/2]).
-export([emit_string/3, emit_object/2, emit_tagged/2]).
-export([emit_encoded/3, emit_array/2, emit_map/2]).

-spec emit_map(Rep, Env) ->
  {Resp, Env} when Rep::term(), Resp::bitstring(), Env::transit_marshaler:env().
emit_map(M, Env) ->
  {MapStart, S1} = transit_marshaler:emit_map_start(Env),
  {Body, S2} = maps:fold(fun (K, V, {In, NS1}) ->
                        {MK, NS2} = transit_marshaler:marshal(?MODULE, K, transit_marshaler:force_as_map_key(true, NS1)),
                        {MV, NS3} = transit_marshaler:marshal(?MODULE, V, transit_marshaler:force_as_map_key(false, NS2)),
                        {<<In/bitstring, MK/bitstring, MV/bitstring>>, NS3}
                    end,
                    {<<>>, S1}, M),
  {MapEnd, S3} = transit_marshaler:emit_map_end(S2),
  {<<MapStart/bitstring, Body/bitstring, MapEnd/bitstring>>, S3}.

emit_string(Tag, Rep, Env) ->
  Escaped = transit_marshaler:escape(Rep),
  emit_object(<<Tag/bitstring, Escaped/bitstring>>, Env).

emit_tagged(_TaggedValue=#tagged_value{tag=Tag, rep=Rep}, Env) ->
  {MapStart, S} = transit_marshaler:emit_map_start(Env),
  S1 = transit_marshaler:force_as_map_key(true, S),
  EncodedTag = transit_rolling_cache:encode(<<?ESC/bitstring, "#", Tag/bitstring>>, transit_marshaler:as_map_key(S1)),
  {Tag1, S2} = emit_object(EncodedTag, S1),
  S3 = transit_marshaler:force_as_map_key(false, S2),
  {Body, S4} =  transit_marshaler:marshal(?MODULE, Rep, S3),
  {MapEnd, S5} = transit_marshaler:emit_map_end(S4),
  {<<MapStart/bitstring, Tag1/bitstring, Body/bitstring, MapEnd/bitstring>>, S5}.

%%% delegate to transit_json_marshaler
emit_object(Rep, Env) ->
  transit_json_marshaler:emit_object(Rep, Env).

emit_array(Rep, Env) ->
  transit_json_marshaler:emit_array(Rep, Env).

emit_boolean(Rep, Env) ->
  transit_json_marshaler:emit_boolean(Rep, Env).

emit_int(Rep, Env) ->
  transit_json_marshaler:emit_int(Rep, Env).

emit_float(Rep, Env) ->
  transit_json_marshaler:emit_float(Rep, Env).

emit_encoded(Tag, Rep, Env) ->
  transit_json_marshaler:emit_encoded(Tag, Rep, Env).

emit_null(Rep, Env) ->
  transit_json_marshaler:emit_null(Rep, Env).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
start_server() ->
  {ok, _} = transit_rolling_cache:start_link(),
  ok.

stop_server(ok) ->
  ok = transit_rolling_cache:stop(),
  ok.

marshals_extention_test_() ->
  {foreach,
   fun start_server/0,
   fun stop_server/1,
   [fun marshals_tagged/1,
    fun marshals_extend/1
   ]}.

marshals_tagged(ok) ->
  Env = transit_marshaler:new_env(),
  Tests = [{<<"{\"~#'\":\"foo\"}">>, "foo"},
           {<<"{\"~#'\":\"foo\"}">>, <<"foo">>},
           {<<"{\"~#'\":1234}">>, 1234}],
  [fun() -> {Res, _} = emit_tagged(#tagged_value{tag=?QUOTE, rep=Rep}, Env) end || {Res, Rep} <- Tests].

marshals_extend(ok) ->
  Env = transit_marshaler:new_env(),
  Tests = [{<<"[\"a\",2,\"~:a\"]">>, ["a", 2, a]},
           {<<"{\"~i3\":4,\"a\":\"b\"}">>, #{3 => 4, "a" => "b"}}],
  [fun() -> {Res, _} = transit_marshaler:marshal_top(?MODULE, Rep, Env) end || {Res, Rep} <- Tests].
-endif.
