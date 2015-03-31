-module(transit_utils).
-export([is_set/1]).
-export([iso_8601_fmt/1]).
-export([iso_8601_to_timestamp/1]).
-export([ms_to_timestamp/1]).
-export([timestamp_to_ms/1]).
-export([datetime_to_ms/1]).
-export([double_to_binary/1]).
-export([map_rep/1]).
-export([uuid_to_string/1]).

is_set(Data) ->
  case ordsets:is_set(Data) of
    true ->
      ordset;
    false ->
      case sets:is_set(Data) of
        true ->
          sets;
        false ->
          case gb_sets:is_set(Data) of
            true ->
              gb_sets;
            false ->
              undefined
          end
      end
  end.

iso_8601_fmt(Timestamp) ->
  {_, _, Low} = Timestamp,
  Millis = Low div 1000,
  DateTime = calendar:now_to_universal_time(Timestamp),
  {{Year,Month,Day},{Hour,Min,Sec}} = DateTime,
  io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.~3.10.0BZ",
                [Year, Month, Day, Hour, Min, Sec, Millis]).

iso_8601_to_timestamp(Rep) ->
  BaseDate = calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
  <<Y:8/binary-unit:4,"-",MM:8/binary-unit:2,"-",D:8/binary-unit:2,"T",H:8/binary-unit:2,":",M:8/binary-unit:2,":",S:8/binary-unit:2,".",MS:8/binary-unit:3,"Z">> = Rep,
  DateTime = lists:map(fun erlang:binary_to_integer/1, [Y,MM,D,H,M,S,MS]),
  UTC = {list_to_tuple(lists:sublist(DateTime, 3)), list_to_tuple(lists:sublist(DateTime, 4, 3))},
  Secs = calendar:datetime_to_gregorian_seconds(UTC) - BaseDate,
  ms_to_timestamp(Secs * 1000 + lists:last(DateTime)).

-spec ms_to_timestamp(integer()) -> erlang:timestamp().
ms_to_timestamp(Ms) when Ms < 0 ->
    case ms_to_timestamp(-1 * Ms) of
        {0,0,Us} -> {0, 0, -1 * Us};
        {0, Secs, Us} -> {0, -1 * Secs, Us};
        {M, S, Us} -> {-1 * M, S, Us}
    end;
ms_to_timestamp(Ms) ->
  Micros = (Ms rem 1000) * 1000,
  Secs = Ms div 1000,
  Megas = Secs div (1000 * 1000),
  Seconds = Secs rem (1000 * 1000),
  {Megas, Seconds, Micros}.

-spec timestamp_to_ms(erlang:timestamp()) -> integer().
timestamp_to_ms({Mega, Sec, Micro}) ->
  MegaSecs = Mega * 1000 * 1000,
  Secs = MegaSecs + Sec,
  (Secs * 1000) + (Micro div 1000).

double_to_binary(Double) ->
  [Rep] = io_lib:format("~w", [Double]),
  list_to_binary(Rep).
  %float_to_binary(F, [{decimals, 4},compact]).

datetime_to_ms({{Y, M, D}, {HH, MM, SS}}) when is_float(SS) ->
  Secs = trunc(SS),
  FSecs = SS - Secs,
  Ms = round(FSecs * 1000),
  datetime_to_ms({{Y, M, D}, {HH, MM, Secs}}, Ms);
datetime_to_ms(DateTime) ->
  datetime_to_ms(DateTime, 0).

datetime_to_ms(DateTime, MsecOffset) ->
  Secs = calendar:datetime_to_gregorian_seconds(DateTime),
  EpochSecs = Secs - 62167219200,
  (EpochSecs * 1000) + MsecOffset.

uuid_to_string([HI, LO]) ->
  <<U0:32, U1:16, U2:16, U3:16, U4:48>> = <<HI:64,LO:64>>,
  lists:flatten(io_lib:format(
                  "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
                  [U0, U1, U2, U3, U4])).

-ifdef(maps_support).
map_rep(PropList) ->
  maps:from_list(PropList).
-else.
map_rep(Ret) ->
  Ret.
-endif.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
date_formatting_test() ->
  A = {946, 728000, 0},
  B = list_to_binary(lists:flatten(iso_8601_fmt(A))),
  ?assertEqual(A, iso_8601_to_timestamp(B)).

timestamp_ms_conversion_test_() ->
  A = {946, 728000, 0},
  B = 946728000000,
  ?_assertEqual(A,ms_to_timestamp(B)),
  ?_assertEqual(B,timestamp_to_ms(A)).

uuid_test() ->
  U = "5a2cbea3-e8c6-428b-b525-21239370dd55",
  ?assertEqual(U, uuid_to_string([6497777973583037067,-5393868542025081515])).
-endif.
