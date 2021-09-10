cowboy-httpserver-template
=====

Automatic Router http server base by Cowboy

# Dependents

`cowboy` Core

`jiffy` JSON Parse

`lager` Logger Tool

`color` Colour Logger plugin 

`jose`  JWT Support

Build
-----

    $ rebar3 compile



# Automatic Router

```erlang
-define(ROUTER, [
    {"/api/[...]", api_router, []}, % This router will automatic
    {"/admin/", cowboy_static, {priv_file, http_server, "admin/index.html"}},
    {"/admin/[...]", cowboy_static, {priv_dir, http_server, "admin/"}},
    {"/", cowboy_static, {priv_file, http_server, "home/index.html"}},
    {"/[...]", cowboy_static, {priv_dir, http_server, "home/"}}
]).
````

`/api/module/function`  will automatic route to `module_control:function`

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

# JSON to maps
JSON will convent to maps , and send to control's function


# Auto Save Upload file
When the content-type is `multipart/form-data` 

It will save the  upload file to `[Priv Dir]/tmp/xxxxx` and send  `#{<<"filetype">> := FileType, <<"path">> := FilePath}` to control's function
