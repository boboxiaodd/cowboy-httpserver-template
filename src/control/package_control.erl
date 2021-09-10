%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 10. Feb 2019 3:46 PM
%%%-------------------------------------------------------------------
-module(package_control).
-author("linhaibo").
-define(CHS(Str), unicode:characters_to_binary(Str)).
-define(SHARE_PASSWORD, "9527").
-export([handle_login/1,handle_app_list/1,handle_pkg_list/1]).
%% API

handle_login(#{<<"password">> := Password}) ->
    case server_common:md5_hex(?SHARE_PASSWORD) == binary_to_list(Password) of
        true ->
            #{ok => 1, path => package_mod:get_oss_path(), token => server_common:get_token(#{uid => 10000, time => os:system_time(second)})};
        false ->
            #{ok => 0, msg => ?CHS("共享密码错误!")}
    end.

handle_app_list(Data) ->
    server_common:check_login(),
    Page = maps:get(<<"page">>, Data, 1),
    {List, HasMore} = package_mod:app_list(Page),
    #{ok => 1, list => List, hasmore => HasMore}.

handle_pkg_list(#{<<"appid">> := AppId , <<"type">> := Type} = Data) ->
    server_common:check_login(),
    Page = maps:get(<<"page">>, Data, 1),
    {List, HasMore} = package_mod:pkg_list_by_appid(AppId,Type,Page),
    #{ok => 1, list => List, hasmore => HasMore}.