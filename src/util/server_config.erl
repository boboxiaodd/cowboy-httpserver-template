%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. Jan 2019 2:42 PM
%%%-------------------------------------------------------------------
-module(server_config).
-author("linhaibo").

-define(MYSQL_NODE,'pk_mysql@172.17.103.0').
-define(MYSQL_MODULE,mysql_client_pool).

%% API
-export([get_mysql_config/0]).


get_mysql_config() ->
    {?MYSQL_NODE, ?MYSQL_MODULE}.