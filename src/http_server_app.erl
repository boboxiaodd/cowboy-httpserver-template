%%%-------------------------------------------------------------------
%% @doc http_server public API
%% @end
%%%-------------------------------------------------------------------

-module(http_server_app).

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1,reload/0]).
-define(ROUTER, [
    {"/api/[...]", api_router, []},
    {"/admin/", cowboy_static, {priv_file, http_server, "admin/index.html"}},
    {"/admin/[...]", cowboy_static, {priv_dir, http_server, "admin/"}},
    {"/", cowboy_static, {priv_file, http_server, "home/index.html"}},
    {"/[...]", cowboy_static, {priv_dir, http_server, "home/"}}
]).

start() ->
    application:start(http_server).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    lager:start(),
    inets:start(),
    application:ensure_all_started(cowboy),
    application:ensure_all_started(jose),
    jose:json_module(jiffy),
    Port = application:get_env(http_server, port, 80),
    Dispatch = cowboy_router:compile([
        {'_', ?ROUTER}
    ]),
    {ok, PId} = cowboy:start_clear(my_80_listener,
        [{port, Port}],
        #{env => #{dispatch => Dispatch}, request_timeout => 120000, max_keepalive => 200}
    ),
    lager:info(server_common:colorformat(magenta, "start http server ~p :~p"), [Port, PId]),
    http_server_sup:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
reload() ->
    Dispatch = cowboy_router:compile(?ROUTER),
    cowboy:set_env(my_web_agent_listener, dispatch, Dispatch),
    lager:info(server_common:colorformat(red, "web_agent RELOAD")).
