[![Build
Status](https://travis-ci.org/isaiah/transit-erlang.svg)](https://travis-ci.org/isaiah/transit-erlang)

transit-erlang
==============
[transit-format](https://github.com/cognitect/transit-format) implementation in Erlang.

Test and developed on Erlang/OTP R17.

Usage
-----

```shell
rebar get-deps compile
erl -pa ebin deps/*/ebin
```

```erlang
A = transit:write(#{<<"a">> => <<"b">>, 3 => 4}, [{format, json}]).
%% => <<"[\"^ \",\"a\",\"b\",3,4]">>
transit:read(A, [{format, json}]).
%% => #{<<"a">> => <<"b">>, 3 => 4}

%%% JSON Verbose mode
transit:write(#{<<"a">> => <<"b">>, 3 => 4}, [{format, json_verbose}]).
%% => <<"{\"~i3\":4,\"a\":\"b\"}">>

%%% msgpack
transit:write(#{<<"a">> => <<"b">>, 3 => 4}, [{format, msgpack}]).
%% => <<149,162,94,32,161,97,161,98,163,126,105,51,4>>
```

Benchmarks
--------------------

These benchmarks are run on a Lenovo Thinkpad W540 with a 16 Gigabyte RAM configuration and the following CPU core:

	Intel(R) Core(TM) i7-4900MQ CPU @ 2.80GHz

Timings run 300 rounds of encoding of the file `transit-format/examples/0.8/example.json` and then we divide down to get the
encoder time for each round. This then forms the base benchmark.

| Commit | Test |  Timing ms |
| ------ | ---- | ------ |
| 3d3b04e | JSON | Read | 9.976 |
| 3d3b04e | JSON | Write | 20.810 |
| 3d3b04e | JSON | ISO | 31.987 |
| 3d3b04e | MsgPack | Read | 4.901 |
| 3d3b04e | MsgPack | Write | 12.072 |
| 3d3b04e | MsgPack | ISO | 15.911 |
| 3d3b04e | JSON_Verbose | Read | 9.724 |
| 3d3b04e | JSON_Verbose | Write | 25.638 |
| 3d3b04e | JSON_Verbose | ISO | 34.236 |
| c976ce6 | JSON | Read | 8.883 |
| c976ce6 | JSON | Write | 18.700 |
| c976ce6 | JSON | ISO | 29.248 |
| c976ce6 | MsgPack | Read | 3.258 |
| c976ce6 | MsgPack | Write | 9.051 |
| c976ce6 | MsgPack | ISO | 11.713 |
| c976ce6 | JSON_Verbose | Read | 9.572 |
| c976ce6 | JSON_Verbose | Write | 27.120 |
| c976ce6 | JSON_Verbose | ISO | 36.613 |

Some important timings are that `jsx` decodes in 5.630 ms and `msgpack` decodes in 0.930 ms. These are therefore the minimum timings and the rest is transit-specific overhead of decoding.

Current limitations
--------------------

* We can't generate a keyword 'true' or false due to the current mapping of atoms into keywords.
* We can't generate a keyword 'nan', 'infinity' or 'neg_infinity' due to special number mappings
* Points-in-time before the date 1/1 1970 are not encoded and decoded correctly.

Default type mapping
--------------------

We currently handle the types in the given table with the given mappings.

*Rationale for the mapping*: The problem we face in Erlang w.r.t transit is that we can't really map external data directly into `atom()` types. The reason is the atom-table is limited and an enemy can easily outrun it. Other language implementations are not with this limit, so they will just use keywords as they go along, ignoring all limitations of them in Erlang. Thus, we opt for a solution where the low-level mapping is to map a lot of things into binary types, but tag them as we do so to discriminate them.

We chose to handle a "naked" `binary()` as an UTF-8 string.

We are currently not able to support:

* Link types

| Transit type | Write accepts             | Read returns              |
| ------------ | -------------             | ------------              |
| null         | undefined                 | undefined                 |
| string       | binary()                  | binary()                  |
| boolean      | true, false               | true, false               |
| integer      | integer()                 | integer()                 |
| decimal      | float()                   | float()                   |
| big integer  | integer()                 | integer()                 |
| time         | {timepoint, now()}        | {timepoint, now()         |
| keyword      | {kw, binary()}            | {kw, binary()}
| symbol       | {sym, binary()}        | {sym, binary()}        |
| uri          | {uri, binary()}           | {uri, binary()}        |
| uuid         | {uuid, binary()}                 | {uuid, binary()}                  |
| bytes		   | {binary, binary()}   | {binary, binary()}  |
| special number | nan, infinity, neg_infinity | nan, infinity, neg_infinity |
| array        | list                      | list                      |
| list         | {list, list(transit())}     | {list, list(transit())}     |
| set          | sets, gb\_sets, ordsets   | sets                      |
| map          | map                       | map                       |
