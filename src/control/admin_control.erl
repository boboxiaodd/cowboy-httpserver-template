%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 10. Feb 2019 3:46 PM
%%%-------------------------------------------------------------------
-module(admin_control).
-author("linhaibo").
-define(CHS(Str), unicode:characters_to_binary(Str)).
%% API
-export([handle_login/1,
    handle_change_pass/1,
    handle_log/1,
    handle_app_list/1,
    handle_add_app/1,
    handle_remove_app/1,
    handle_upload_logo/1,
    handle_add_package/1,
    handle_package_list/1,
    handle_remove_package/1,
    handle_upload_package/1, handle_del_file/1]).

handle_login(#{<<"username">> := UserName, <<"password">> := Password}) ->
    case admin_mod:auth(UserName, Password) of
        true ->
            #{ok => 1, path => package_mod:get_oss_path(), token => server_common:get_token(#{uid => UserName, time => os:system_time(second)})};
        false -> #{ok => 0, msg => ?CHS("用户或密码错误!")}
    end.

handle_change_pass(#{<<"password">> := Password}) ->
    server_common:check_login(),
    case admin_mod:change_pass(get(uid), Password) of
        true ->
            #{ok => 1, msg => ?CHS("修改成功!下次登录生效。")};
        false -> #{ok => 0, msg => ?CHS("修改失败！")}
    end.

handle_log(_Data) ->
    server_common:check_login(),
    List = admin_mod:log_list(20),
    #{ok => 1, list => List}.

handle_del_file(#{<<"path">> := Path}) ->
    server_common:check_login(),
    package_mod:del_file_to_oss(binary_to_list(Path)),
    #{ok => 1}.

handle_remove_app(#{<<"ids">> := Ids}) ->
    server_common:check_login(),
    StrIds = check_ids(Ids),
    lager:info("StrIds:~s", [StrIds]),
    L = admin_mod:get_app_by_ids(StrIds),
    lists:foreach(fun(#{<<"app_logo">> := Url}) ->
        lager:info("remove app logo: ~p", [Url]),
        package_mod:del_file_to_oss(binary_to_list(Url))
                  end, L),
    Res = admin_mod:remove_app_by_ids(StrIds),
    Log = jiffy:encode(#{event => <<"delapp">>, count => length(Ids)}),
    admin_mod:add_log(get(uid),Log),
    #{ok => 1, res => Res}.


handle_app_list(Data) ->
    server_common:check_login(),
    Page = maps:get(<<"page">>, Data, 1),
    {ArtistList, HasMore} = package_mod:app_list(Page),
    #{ok => 1, list => ArtistList, hasmore => HasMore}.

handle_add_app(#{<<"app_name">> := Name, <<"id">> := Id, <<"app_logo">> := Logo, <<"app_desc">> := Memo, <<"app_bundle_id">> := BundleId}) ->
    server_common:check_login(),
    case admin_mod:app_add(Name, Logo, BundleId, Memo, Id) of
        fale -> #{ok => 0, msg => ?CHS("增加失败!")};
        _ ->
            Log = jiffy:encode(#{event => <<"addapp">>,app => Name}),
            admin_mod:add_log(get(uid),Log),
            #{ok => 1}
    end.

handle_upload_logo(#{<<"filetype">> := FileType, <<"path">> := FilePath}) ->
    server_common:check_login(),
    ExtStr = case FileType of
                 <<"image/jpeg">> -> "jpg";
                 <<"image/png">> -> "png";
                 _ ->
                     file:delete(FilePath),
                     throw({error, bad_file})
             end,
    Mtime = os:system_time(millisecond),
    OSSPath = "logo/" ++ integer_to_list(Mtime) ++ "." ++ ExtStr,
    package_mod:put_file_to_oss(FilePath, OSSPath),
    file:delete(FilePath),
    #{ok => 1, filepath => list_to_binary(OSSPath)}.



handle_package_list(#{<<"type">> := Type} = Data) ->
    server_common:check_login(),
    Page = maps:get(<<"page">>, Data, 1),
    {List, HasMore} = package_mod:pkg_list(Type, Page),
    #{ok => 1, list => List, hasmore => HasMore}.


handle_add_package(#{<<"pk_name">> := Name,<<"type">> := AppType , <<"pk_env">> := Env, <<"pk_url">> := Url, <<"pk_version">> := Version} = Data) ->
    server_common:check_login(),
    #{<<"id">> := AppId, <<"app_logo">> := Logo, <<"app_bundle_id">> := BundleId, <<"app_name">> := AppName} =
        case admin_mod:get_app_by_name(Name) of
            [AppInfo] ->
                AppInfo;
            _ ->
                throw({error, bad_arg})
        end,
    PId = maps:get(<<"id">>, Data, 0),
    case PId == 0 of
        true ->
            PlistUrl = case AppType of
                           1 -> %% iOS
                               PathBase = package_mod:get_oss_path(),
                               {ok, Bin} = file:read_file(code:priv_dir(http_server) ++ "/manifest.plist"),
                               L = [
                                   {<<"{{PACKAGE_URL}}">>, <<PathBase/binary,"/",Url/binary>>},
                                   {<<"{{PACKAGE_LOGO}}">>, <<PathBase/binary,"/",Logo/binary>>},
                                   {<<"{{PACKAGE_BUNDLE_ID}}">>, BundleId},
                                   {<<"{{PACKAGE_VERSION}}">>, Version},
                                   {<<"{{PACKAGE_NAME}}">>, AppName}
                               ],
                               Mtime = os:system_time(millisecond),
                               BinPlist = do_replace(Bin, L),
                               OSSPath = "plist/" ++ integer_to_list(Mtime) ++ ".plist",
                               package_mod:put_bin_to_oss(BinPlist, OSSPath),
                               OSSPath;
                           _ -> %% Andorid
                               <<"">>
                       end,
            case admin_mod:package_add(AppId,AppType, Name, Version, Url, PlistUrl, Env,PId) of
                false -> #{ok => 0, msg => ?CHS("增加失败!")};
                _ ->
                    Log = jiffy:encode(#{event => <<"addpkg">>, type => AppType ,app => AppName, version => Version }),
                    admin_mod:add_log(get(uid),Log),
                    #{ok => 1}
            end;
        false ->
            case admin_mod:package_add(0, AppType, Name, Version, Url, <<"">>, Env, PId) of
                false -> #{ok => 0, msg => ?CHS("增加失败!")};
                _ ->
                    Log = jiffy:encode(#{event => <<"addpkg">>, type => AppType ,app => AppName, version => Version }),
                    admin_mod:add_log(get(uid),Log),
                    #{ok => 1}
            end
    end.

handle_remove_package(#{<<"ids">> := Ids}) ->
    server_common:check_login(),
    StrIds = check_ids(Ids),
    lager:info("StrIds:~s", [StrIds]),
    L = admin_mod:get_package_by_ids(StrIds),
    lists:foreach(fun(#{<<"pk_url">> := Url, <<"pk_plisturl">> := PlistUrl}) ->
        lager:info("remove photo: ~p", [Url]),
        case PlistUrl =/= <<>> of
            true -> package_mod:del_file_to_oss(binary_to_list(PlistUrl));
            false -> ok
        end,
        package_mod:del_file_to_oss(binary_to_list(Url))
                  end, L),
    Res = admin_mod:remove_package_by_ids(StrIds),
    Log = jiffy:encode(#{event => <<"delpkg">>, count => length(Ids)}),
    admin_mod:add_log(get(uid),Log),
    #{ok => 1, res => Res}.


handle_upload_package(#{<<"filetype">> := FileType, <<"path">> := FilePath}) ->
    server_common:check_login(),
    ExtStr = case FileType of
                 <<"application/apk">> -> "apk";
                 <<"application/ipa">> -> "ipa";
                 _ ->
                     file:delete(FilePath),
                     throw({error, bad_file})
             end,
    Mtime = os:system_time(millisecond),
    Peer = erlang:phash2(Mtime, 10),
    OSSPath = ExtStr ++ "/" ++ integer_to_list(Peer) ++ "/" ++ integer_to_list(Mtime) ++ "." ++ ExtStr,
    package_mod:put_file_to_oss(FilePath, OSSPath),
    file:delete(FilePath),
    #{ok => 1, filepath => list_to_binary(OSSPath)}.


%%Private API
check_ids(Ids) ->
    NewIds = lists:filtermap(fun(Item) ->
        {is_integer(Item), integer_to_list(Item)}
                             end, Ids),
    lists:join(",", NewIds).


do_replace(Bin, []) ->
    Bin;
do_replace(Bin, [H | T]) ->
    {Pattern, Replacement} = H,
    NewBin = binary:replace(Bin, Pattern, Replacement, [global]),
    do_replace(NewBin, T).