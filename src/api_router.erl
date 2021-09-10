%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 22. 九月 2018 上午9:39
%%%-------------------------------------------------------------------
-module(api_router).
-author("linhaibo").
-export([init/2, terminate/3]).
-define(CHS(Str), unicode:characters_to_binary(Str)).

%% 初始化参数，存入进程字典，进程字典结构:
%% ------------------------
%% ip       Client IP
%% method   请求的方式 POST,OPTIONS   GET方式不被允许
%% path     请求的路径
%% auth     验证状态: false 表示无需认证, true 认证通过 , relogin 认证通过但需要重新获取Token
%% uid      0 表示无需认证 其他表示当前的UId
%% ------------------------
init(Req, Opts) ->
    Method = cowboy_req:method(Req),
    Ip = cowboy_req:peer(Req),
    Path = cowboy_req:path(Req),
    lager:info(server_common:colorformat(green, "Path:~p IP: ~p,Method:~p"), [Path, Ip, Method]),
    put(ip, Ip),
    put(method, Method),
    put(path, Path),
    try
        is_auth(Req), %%  进程字典存入 uid,auth
        Data = get_data(Req),
        lager:info(server_common:colorformat(green, "RECV Data: ~p"), [Data]),
        Result = router(Data),
        response(Result, Req)
    catch
        _:Reason:Trace ->
            case Reason of
                {error, bad_file} -> response(#{ok => 0, msg => ?CHS("上传的文件格式不支持！")}, Req);
                {error, bad_arg} -> response(#{ok => 0, msg => ?CHS("无法识别参数!")}, Req);
                {error, options} -> response(options, Req);
                {error, Type} ->
                    lager:error("[~p]Reason:, ~p ~n ~p", [get(path), Reason, Trace]),
                    response(Type, Req);
                _ ->
                    lager:error("[~p]Reason:, ~p ~n ~p", [get(path), Reason, Trace]),
                    response(bad_command, Req)
            end
    end,
    {ok, Req, Opts}.

terminate(Reason, _Req, _State) ->
    lager:info(server_common:colorformat(blackb, "process terminate with reason:~p"), [Reason]),
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Private Function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_data(Req) ->
    case get(method) of
        <<"POST">> ->
            case cowboy_req:parse_header(<<"content-type">>, Req) of
                {<<"multipart">>, <<"form-data">>, _} ->
                    multipart(Req, #{});
                _ ->
                    case cowboy_req:has_body(Req) of
                        true ->
                            {ok, Body, _} = cowboy_req:read_body(Req),
                            jiffy:decode(Body, [return_maps, copy_strings]);
                        false ->
                            #{}
                    end
            end;
        
        <<"OPTIONS">> ->
            throw({error, options});
        _ -> throw({error, method_not_allow})
    end.

router(Data) ->
    case binary:split(get(path), <<"/">>, [global]) of
        [_, _, BinModule | BinControl] ->
            Mod = binary_to_existing_atom(<<BinModule/binary, "_control">>, latin1),
            BinControl1 = list_to_binary(BinControl),
            Fun = try
                      binary_to_existing_atom(<<"handle_", BinControl1/binary>>, latin1)
                  catch
                      _:_ ->
                          lager:info(server_common:colorformat(blackb, "can find ~p:handle_~s and retry..."), [Mod,BinControl1]),
                          _ = Mod:module_info(exports),
                          binary_to_existing_atom(<<"handle_", BinControl1/binary>>, latin1)
                  end,
            apply(Mod, Fun, [Data]);
        _ -> throw({error, bad_command})
    end.


response(verify_timeout, Req) ->
    response(#{ok => 0, msg => <<"VERIFY_TIMEOUT">>, relogin => 1}, Req);
response(verify_fail, Req) ->
    response(#{ok => 0, msg => <<"VERIFY_FAIL">>}, Req);
response(bad_protocol, Req) ->
    response(#{ok => 0, msg => <<"BAD_PROTOCOL">>}, Req);
response(bad_token, Req) ->
    response(#{ok => 0, msg => <<"BAD_TOKEN">>}, Req);
response(options, Req) ->
    cowboy_req:reply(200, #{
        <<"Access-Control-Allow-Origin">> => <<"*">>,
        <<"Access-Control-Allow-Methods">> => <<"POST,GET,OPTIONS">>,
        <<"Access-Control-Allow-Headers">> => <<"authorization,content-type">>
    }, Req);
response(undefined, Req) ->
    cowboy_req:reply(400, Req);
response(method_not_allow, Req) ->
    cowboy_req:reply(405, Req);
response(bad_command, Req) ->
    cowboy_req:reply(404, Req);
response(#{ok := 303, url := Url}, Req) ->
    cowboy_req:reply(303, #{<<"location">> => list_to_binary(Url)}, <<>>, Req);
response(Response, Req) ->
    case Response of
        #{list := L } ->
            lager:info(server_common:colorformat(green, "SEND Data: ~p"), [Response#{list => length(L)}]);
        _ ->
            lager:info(server_common:colorformat(green, "SEND Data: ~p"), [Response])
    end,
    
    
    Reply = case get(auth) of
                false -> jiffy:encode(Response);
                Flag -> jiffy:encode(Response#{auth_flag => Flag})
            end,
    ContentType = <<"application/json">>,
    cowboy_req:reply(200, #{
        <<"Access-Control-Allow-Origin">> => <<"*">>,
        <<"Access-Control-Allow-Methods">> => <<"POST,GET,OPTIONS">>,
        <<"Access-Control-Allow-Headers">> => <<"authorization,content-type">>,
        <<"content-type">> => ContentType
    }, Reply, Req).

is_auth(Req) ->
    BinHeader = cowboy_req:header(<<"authorization">>, Req, <<"">>),
    case binary:split(BinHeader, <<" ">>) of
        [_, JWTToken] ->
            case server_common:verify_token(JWTToken) of
                {ok, UId, Flag} ->
                    put(auth, Flag),
                    put(uid, UId);
                Error ->
                    lager:info("bad_token:~p", [Error]),
                    throw({error, bad_token})
            end;
        _ ->
            put(auth, false),
            put(uid,0)
    end.

multipart(Req0, Res) ->
    case cowboy_req:read_part(Req0) of
        {ok, Headers, Req1} ->
            {Req, NewRes} = case cow_multipart:form_data(Headers) of
                                {data, FieldName} ->
                                    {ok, Body, Req2} = cowboy_req:read_part_body(Req1),
                                    {Req2, Res#{FieldName => Body}};
                                {file, _FieldName, _Filename, _CType} ->
                                    {Req2, Bin} = stream_file(Req1, <<>>),
                                    Seed = os:system_time(second),
                                    Path = code:priv_dir(http_server) ++ "/tmp/" ++ integer_to_list(Seed),
                                    file:write_file(Path, Bin, [binary]),
                                    {Req2, Res#{<<"path">> => list_to_binary(Path)}}
                            end,
            multipart(Req, NewRes);
        {done, _Req} ->
            Res
    end.

stream_file(Req0, Bin) ->
    case cowboy_req:read_part_body(Req0) of
        {ok, LastBodyChunk, Req} ->
            {Req, <<Bin/binary, LastBodyChunk/binary>>};
        {more, BodyChunk, Req} ->
            stream_file(Req, <<Bin/binary, BodyChunk/binary>>)
    end.