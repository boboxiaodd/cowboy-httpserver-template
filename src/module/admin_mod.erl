%%%-------------------------------------------------------------------
%%% @author linhaibo
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 11. Feb 2019 4:21 PM
%%%-------------------------------------------------------------------
-module(admin_mod).
-author("linhaibo").
%% API
-export([auth/2,change_pass/2,get_app_by_ids/1,remove_app_by_ids/1,add_log/2,log_list/1,get_app_by_name/1,app_add/5,app_remove/1,package_add/8,get_package_by_ids/1,remove_package_by_ids/1]).
-define(PAGE_COUNT,20).

auth(Username,Password) ->
    case server_common:mysql_query("select * from tb_admin where username = ? limit 1",[Username]) of
        [#{<<"password">> := Password }] ->
            %%todo add login logger..
            true;
        _ -> false
    end.
change_pass(UId,Password) ->
    case server_common:mysql_query("update tb_admin set password = ?  where  username = ? limit 1",[Password,UId],affected) of
        1 ->
            true;
        _ ->
            false
    end.

add_log(UId,Content) ->
    Uptime = os:system_time(second),
    case server_common:mysql_query("insert into tb_log (uid,content,uptime) values (?,?,?)",[UId,Content,Uptime],insert_id) of
        Id when is_integer(Id)-> Id;
        _ -> false
    end.

log_list(Count) ->
    case server_common:mysql_query("select * from tb_log order by id desc limit ?", [Count]) of
        List when is_list(List) ->
            List;
        _ -> []
    end.


get_app_by_name(Name) ->
    case server_common:mysql_query("select * from tb_app where app_name = ?", [Name]) of
        List when is_list(List) ->
            List;
        _ -> []
    end.

app_add(Name,Logo,BundleId,Memo,Id) ->
    case Id of
        0 ->
            case server_common:mysql_query("insert into tb_app (app_name,app_logo,app_bundle_id,app_desc) values (?,?,?,?)",[Name,Logo,BundleId,Memo],insert_id) of
                Id when is_integer(Id)-> Id;
                _ -> false
            end;
        _ ->
            case server_common:mysql_query("update tb_app set app_name = ? ,app_logo =? ,app_bundle_id = ? ,app_desc =? where id = ?",[Name,Logo,BundleId,Memo,Id],affected) of
                Id when is_integer(Id)-> Id;
                _ -> false
            end
    end.

app_remove(_Id) ->
    ok.
package_add(AppId,AppType,Name,Version,Url,PlistUrl,Env,PId) ->
    Uptime = os:system_time(second),
    case PId of
        0 ->
            case server_common:mysql_query("insert into tb_package (pk_appid,pk_type,pk_name,pk_version,pk_url,pk_plisturl,pk_uptime,pk_env) values (?,?,?,?,?,?,?,?)",[AppId,AppType,Name,Version,Url,PlistUrl,Uptime,Env],insert_id) of
                Id when is_integer(Id)->
                    server_common:mysql_query("update tb_app set app_uptime = ? where app_id = ?",[Uptime,AppId],affected),
                    Id;
                _ -> false
            end;
        _ ->
            case server_common:mysql_query("update tb_package set pk_name =? ,pk_version =? , pk_url =? , pk_uptime = ? , pk_env =?  where id = ?",[Name,Version,Url,Uptime,Env,PId],affected) of
                Id when is_integer(Id)-> Id;
                _ -> false
            end
    end.

get_app_by_ids(Ids) ->
    case server_common:mysql_query("select * from tb_app where id in (" ++ Ids ++ ") order by id desc limit 100", []) of
        List when is_list(List) ->
            List;
        _ -> []
    end.

remove_app_by_ids(Ids) ->
    case server_common:mysql_query("delete from tb_app where id in (" ++ Ids ++ ")", []) of
        Res when is_integer(Res) ->
            Res;
        _ -> 0
    end.

get_package_by_ids(Ids) ->
    case server_common:mysql_query("select * from tb_package where id in (" ++ Ids ++ ") order by id desc limit 100", []) of
        List when is_list(List) ->
            List;
        _ -> []
    end.

remove_package_by_ids(Ids) ->
    case server_common:mysql_query("delete from tb_package where id in (" ++ Ids ++ ")", []) of
        Res when is_integer(Res) ->
            Res;
        _ -> 0
    end.
