cowboy-httpserver-template
=====

Automatic Router http server base by Cowboy

# Dependents

`cowboy` Core

`jiffy` JSON Parse

`lager` Logger Tool

`color` Colour Logger plugin 

`jose`  JWT Support

Build and Run
-----

    $ rebar3 compile
    $ server-ctl start
    
For more command , see `server-ctl help`


# Automatic Router

```erlang
-define(ROUTER, [
    {"/api/[...]", api_router, []}, % This router will automatic
    {"/api_v1/[...]", api_router, []}, % This router will automatic
    {"/admin/", cowboy_static, {priv_file, http_server, "admin/index.html"}},
    {"/admin/[...]", cowboy_static, {priv_dir, http_server, "admin/"}},
    {"/", cowboy_static, {priv_file, http_server, "home/index.html"}},
    {"/[...]", cowboy_static, {priv_dir, http_server, "home/"}}
]).
````

`/api/module/function`  will automatic route to `module_control:function` (the suffix `_control` is very important for security)

the function's arguments is a maps from request JSON body

If add a new control , it will try to apply `Mod:module_info` to active module . 

```erlang
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
```

# Hot reload cowboy router

First change ROUTER , and exectue :

`server-ctl graceful`


# Auto Save Upload file
When the content-type is `multipart/form-data` 

It will save the  upload file to `[Priv Dir]/tmp/xxxxx` and add `path` to maps which send to control' function, like  

`#{<<"Param1">> := Param1, <<"Param2">> := Param2 , <<"path">> := FilePath}` 

You can change it according to your needs

# Usage
Modify Listener port in file `priv/app.config`

Reference example from `src/control/*` and create your control
