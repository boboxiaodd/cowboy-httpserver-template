-module(server_manage).
-export([check/1, start/2, shutdown/1, restart/1, status/1, execute/4]).

check({Node}) ->
	case net_kernel:connect_node(Node) of
		true -> io:format("true");
		false -> io:format("false")
	end.

status({Node}) ->
	case net_kernel:connect_node(Node) of
		true ->
			case rpc:call(Node, erlang, is_alive, []) of
				true ->
					io:format("Node: [\e[32m~s\e[00m]  [\e[32m is Running \e[00m]  ... ", [Node]),
					io:format("\e[01;32mok\e[00m~n");
				_ ->
					io:format("Node: [\e[32m~s\e[00m] [\e[31m has Shutdown \e[00m]   ...", [Node])
			end;
		false ->
			io:format("fail~n")
	end,
	halt().

shutdown({Node, Service}) ->
	case net_kernel:connect_node(Node) of
		true ->
			io:format("Application: [\e[32m~s\e[00m] Stop...", [Service]),
			case rpc:call(Node, application, stop, [Service]) of
				{badrpc, nodedown} ->
					io:format("[\e[01;31mERROR: application not start...\e[00m]~n");
				{badrpc, _} ->
					io:format("\e[01;31mfail\e[00m~n"),
					io:format("Node: [\e[32m~s\e[00m] Shutdown ... ", [Node]),
					rpc:call(Node, erlang, halt, [0]),
					io:format("\e[01;32mok\e[00m~n");
				_ ->
					io:format("\e[01;32mok\e[00m~n"),
					io:format("Node: [\e[32m~s\e[00m] Shutdown ... ", [Node]),
					rpc:call(Node, init, stop, []),
					io:format("\e[01;32mok\e[00m~n")
			end;
		false ->
			io:format("[\e[01;31mERROR\e[00m] Can't connect [\e[01;36m~p\e[00m] ...~n", [Node])
	end,
	halt().

execute(N, M, F, A) ->
	case net_kernel:connect_node(N) of
		true ->
			case rpc:call(N, M, F, A) of
				{badrpc, nodedown} ->
					io:format("[\e[01;31mERROR: application not start...\e[00m]~n");
				_ ->
					io:format("\e[0;32m Execute ~p:~p(~p) ok ...\e[00m~n", [M, F, A])
			end;
		false ->
			io:format("[\e[01;31mERROR\e[00m] Can't connect [\e[01;36m~p\e[00m] ...~n", [N])
	end,
	halt().

start(Node, StartArg) ->
	case net_kernel:connect_node(Node) of
		true -> io:format("[\e[01;31mERROR\e[00m] [\e[01;36m~p\e[00m] already start...~n", [Node]);
		false ->
			io:format("[\e[32mExecute\e[00m]\e[36m~s\e[00m ... ", [StartArg]),
			os:cmd(StartArg),
			io:format("\e[32mok\e[00m~n")
	end,
	halt().

restart({Node, Service, Module}) ->
	case net_kernel:connect_node(Node) of
		true ->
			_Ret = rpc:call(Node, code, purge, [Module]),
			io:format("~p: [\e[31m~s\e[00m] Reload Module [\e[31m~s\e[00m]...", [Node, Service, Module]),
			Ret2 = rpc:call(Node, code, load_file, [Module]),
			io:format("\e[01;32m~p\e[00m~n", [Ret2]);
		false ->
			io:format("fail~n")
	end,
	halt().
