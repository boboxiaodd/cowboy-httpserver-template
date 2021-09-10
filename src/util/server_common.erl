%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 25. 八月 2018 下午11:32
%%%-------------------------------------------------------------------
-module(server_common).
-author("linhaibo").
-define(TOKEN_EXT_TIMOUT, 600).
-define(TOKEN_TIMEOUT, 3600 * 24).
-define(SECURT_KEY, <<"33e0d209a281cc5b29fb9c05e4ff1fb0">>).
-define(ALGORITHM, hs256).
-define(ALG,#{alg => jose_jws_alg_hmac}).

-record(jose_jwt, {
    fields = #{} :: map()
}).

-define(JWK,#{<<"kty">> => <<"oct">>, <<"k">> => ?SECURT_KEY }).
-define(JWS,#{<<"alg">> => <<"HS256">>}).

%% API
-export([colorformat/2,to_list/1,md5_hex/1,to_integer/1,to_float/1,to_binary/1,check_login/0]).
-export([mysql_query/2,mysql_query/3,get_token/1,verify_token/1]).

to_list(A) when is_binary(A) -> binary_to_list(A);
to_list(A) when is_list(A) -> A;
to_list(A) when is_integer(A) -> integer_to_list(A);
to_list(A) when is_float(A) -> float_to_list(A, [{decimals, 2}]);
to_list(A) -> A.

to_integer(A) when is_binary(A) ->
    if
        A == <<"null">>; A == <<"">> ->
            0;
        true ->
            binary_to_integer(A)
    end;
to_integer(A) when is_list(A) -> list_to_integer(A);
to_integer(A) -> A.

to_binary(A) when is_integer(A) -> integer_to_binary(A);
to_binary(A) when is_list(A) -> list_to_binary(A);
to_binary(A) when is_float(A) -> float_to_binary(A);
to_binary(A) -> A.

to_float(A) when is_binary(A) -> binary_to_float(A);
to_float(A) -> A.


colorformat(F, Formater) ->
    [A, T, E] = apply(color, F, [Formater]),
    string:join([pid_to_list(self()), " ", binary_to_list(A), T, binary_to_list(E)], "").

check_login() ->
    case get(auth) of
        false -> throw({error,bad_token});
        _ -> ok
    end.

mysql_query(Sql, Param) ->
    mysql_query(Sql, Param, select).
mysql_query(Sql, Param, Flag) ->
    {N, M} = server_config:get_mysql_config(),
    rpc:call(N, M, query, [Sql, Param, Flag]).

verify_token(JWTToken) ->
    try jose_jwt:verify(?JWK, {?ALG,JWTToken}) of
        {true, #jose_jwt{fields = #{<<"uid">> := UId, <<"time">> := Time}},_} ->
            lager:info("uid:~p,time:~p",[UId,Time]),
            Now = os:system_time(second),
            if
                Now - Time > ?TOKEN_TIMEOUT ->
                    case check_token_timeout(UId, Now) of
                        true -> {error, verify_timeout};
                        false -> {ok, UId, relogin}
                    end;
                true -> {ok, UId , true }
            end;
        _ ->
            {error, verify_fail}
    catch
        _:_ ->
            {error, bad_token}
    end.

check_token_timeout(UId, Now) ->
    BinUId = integer_to_binary(UId),
    Key = <<BinUId/binary, "_token_timeout">>,
    {N, M} = server_config:get_redis_config(),
    case rpc:call(N, M, get, [Key]) of
        undefined -> %key不存在，创建redis
            {N, M} = server_config:redis_config(),
            rpc:cast(N, M, set, [Key, integer_to_list(Now), integer_to_list(3600 * 24)]),
            false;
        Timestamp -> %key存在，如果还超时，则抛出 verify_timeout,拒绝请求
            Now - binary_to_integer(Timestamp) > ?TOKEN_EXT_TIMOUT
    end.

get_token(Json) ->
    Sign = jose_jwt:sign(?JWK,?JWS,Json),
    {_,Token} = jose_jws:compact(Sign),
    Token.



md5_hex(S) ->
    Md5_bin = erlang:md5(S),
    Md5_list = binary_to_list(Md5_bin),
    lists:flatten(list_to_hex(Md5_list)).
list_to_hex(L) -> lists:map(fun(X) -> int_to_hex(X) end, L).
int_to_hex(N) when N < 256 -> [hex(N div 16), hex(N rem 16)].
hex(N) when N < 10 -> $0 + N;
hex(N) when N >= 10, N < 16 -> $a + (N - 10).
%%    jwerl:sign(Json, ?ALGORITHM, ?SECURT_KEY).
