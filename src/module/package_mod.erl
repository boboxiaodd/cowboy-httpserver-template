%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 10. Feb 2019 8:06 PM
%%%-------------------------------------------------------------------
-module(package_mod).
-author("linhaibo").
-define(OSS_ACCESSKEY_ID,"LTAIG02Fe5Bsakdm").
-define(OSS_SECRET,<<"xuhaIYru0188bsLKRRXEXWxZDRnNHh">>).
-define(OSS_LAN_URL,"http://pkg-man.oss-cn-beijing-internal.aliyuncs.com").
-define(OSS_WAN_URL,<<"https://pkg-man.oss-cn-beijing.aliyuncs.com">>).
-define(PAGE_COUNT,20).
%% API
-export([put_file_to_oss/2,put_bin_to_oss/2,del_file_to_oss/1,get_oss_path/0]).
-export([app_list/1,pkg_list/2,pkg_list_by_appid/3]).

put_file_to_oss(FilePath,OSSPath) ->
    {ok, Bin } = file:read_file(FilePath),
    Header = get_oss_header("PUT",OSSPath),
    Host = ?OSS_LAN_URL ++ "/" ++ OSSPath,
    Result = httpc:request(put, {Host, Header,[],Bin}, [], []),
    lager:info(server_common:colorformat(white, "request_oss_result:~p"), [Result]).

put_bin_to_oss(Bin,OSSPath) ->
    Header = get_oss_header("PUT",OSSPath),
    Host = ?OSS_LAN_URL ++ "/" ++ OSSPath,
    Result = httpc:request(put, {Host, Header,[],Bin}, [], []),
    lager:info(server_common:colorformat(white, "request_oss_result:~p"), [Result]).

del_file_to_oss(OSSPath) ->
    Header = get_oss_header("DELETE",OSSPath),
    Host = ?OSS_LAN_URL ++ "/" ++ OSSPath,
    Result = httpc:request(delete, {Host, Header,[],[]}, [], []),
    lager:info(server_common:colorformat(white, "request_oss_result:~p"), [Result]).

get_oss_path() ->
    ?OSS_WAN_URL.


app_list(Page) ->
    Start = (Page - 1) * ?PAGE_COUNT,
    Size = ?PAGE_COUNT + 1,
    case server_common:mysql_query("select * from tb_app order by app_uptime desc limit ?, ?", [Start, Size]) of
        Artist when is_list(Artist) ->
            HasMore = length(Artist) > ?PAGE_COUNT,
            case HasMore of
                true ->
                    {lists:droplast(Artist), HasMore};
                _ ->
                    {Artist, HasMore}
            end;
        _ -> {[], false}
    
    end.

pkg_list(Type,Page) ->
    Start = (Page - 1) * ?PAGE_COUNT,
    Size = ?PAGE_COUNT + 1,
    case server_common:mysql_query("select * from tb_package where pk_type = ? order by id desc limit ?, ?", [Type, Start, Size]) of
        Artist when is_list(Artist) ->
            HasMore = length(Artist) > ?PAGE_COUNT,
            case HasMore of
                true ->
                    {lists:droplast(Artist), HasMore};
                _ ->
                    {Artist, HasMore}
            end;
        _ -> {[], false}
    
    end.

pkg_list_by_appid(Id,Type,Page) ->
    Start = (Page - 1) * ?PAGE_COUNT,
    Size = ?PAGE_COUNT + 1,
    case server_common:mysql_query("select A.*,B.app_logo from tb_package as A left join tb_app as B on A.pk_appid = B.id where pk_appid = ? and pk_type = ?  order by id desc limit ?, ?", [Id,Type, Start, Size]) of
        Artist when is_list(Artist) ->
            HasMore = length(Artist) > ?PAGE_COUNT,
            case HasMore of
                true ->
                    {lists:droplast(Artist), HasMore};
                _ ->
                    {Artist, HasMore}
            end;
        _ -> {[], false}
    
    end.

%% Private API
get_oss_header(Method,Path) ->
    [TT] = calendar:local_time_to_universal_time_dst(calendar:local_time()),
    Time = binary_to_list(cow_date:rfc7231(TT)),
    Str = io_lib:format("~s~n~n~n~s~n/pkg-man/~s", [Method,Time, Path]),
    Signature = base64:encode(crypto:hmac(sha, ?OSS_SECRET, list_to_binary(Str))),
    [{"Authorization", "OSS " ++ ?OSS_ACCESSKEY_ID ++ ":" ++ binary_to_list(Signature)}, {"Date", Time}].
