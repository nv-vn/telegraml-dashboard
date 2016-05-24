open Telegram
open Batteries
open Opium.Std

module MkDashboard (B : Api.BOT) = struct
  let start_time = ODate.Unix.now ()

  module ChatSet = Set.Make (struct
      open Api.Chat

      type t = chat

      let compare {id=id1} {id=id2} = Int.compare id1 id2
    end)

  let save_chats ~chats =
    let insert chat =
      let chat_info = DashboardDb.prepare_chat chat in
      DashboardDb.add_chat ~chat_info () in
    ChatSet.iter insert chats

  let load_chats () =
    let chats = DashboardDb.get_chats () in
    let open Api.Chat in
    let rec make_set = function
      | [] -> ChatSet.empty
      | chat::chats -> ChatSet.add (Yojson.Safe.from_string chat |> read) (make_set chats) in
    make_set chats

  let chats = ref @@ load_chats ()

  let get_chats () = ChatSet.elements !chats

  let add_chat chat =
    chats := ChatSet.add chat !chats;
    save_chats !chats

  let remove_chat chat =
    chats := ChatSet.add chat !chats;
    save_chats !chats

  include Api.Mk (struct
      include B

      let new_chat_member chat member =
        let open Api.User in
        if member.username = B.command_postfix then (* Same username *)
          add_chat chat
        else ();
        B.new_chat_member chat member

      let left_chat_member chat member =
        let open Api.User in
        if member.username = B.command_postfix then (* Same username *)
          remove_chat chat
        else ();
        B.left_chat_member chat member
    end)

  module Web = struct
    let stylesheet =
      {css|
        html {
          padding: 20px;
          text-align: center;
          text-size: 200%;
          font-family: "Arial Black", Gadget, sans-serif;
        }

        table {
          width: 40%;
          margin: 2px;
          border-collapse: collapse;
        }

        tr, td {
          border: 1px solid #999;
          text-align: center;
        }

        .toggle {
          color: #ffffff;
          margin: 2px;
          padding: 10px;
          font-size: 20px;
          background: #3498db;
          text-decoration: none;
          border-style: none;
        }

        .toggle:hover {
          background: #3cb0fd;
          text-decoration: none;
          border-style: none;
        }
      |css}

    let extract_or_error f lwt default =
      match Lwt_main.run lwt with
      | Api.Result.Success x -> f x
      | Api.Result.Failure _ -> default

    let username =
      let name_of_user {Api.User.username; Api.User.first_name} =
        match username with
        | Some x -> x
        | _ -> first_name in
      extract_or_error name_of_user get_me "Unknown user"

    let create_header text =
      Printf.sprintf {|<h1>%s</h1>|} text

    let create_submit_button text =
      Printf.sprintf {|<input type="submit" class="toggle" value="%s"/>|} text

    let create_post_form action fields =
      Printf.sprintf {|<form action="%s" method="POST">%s</form>|} action fields

    let create_table_row items =
      {|<tr><td>|} ^ String.concat {|</td><td>|} items ^ {|</td></tr>|}

    let create_table headers rows =
      let headers' = create_table_row headers
      and rows' = List.map create_table_row rows |> String.concat "" in
      Printf.sprintf {|<table>%s%s</table>|} headers' rows'

    let create_document title bodies =
      Printf.sprintf
        {|<html><head><title>TelegraML Dashboard - %s</title><style>%s</style></head><body><div align="CENTER">%s</div></body></html>|}
        title
        stylesheet
        (String.concat "" bodies)

    let list_commands () =
      let row_of_command cmd =
        let open Api.Command in
        let enabled = match cmd.enabled with
          | true -> "Enabled"
          | false -> "Disabled" in
        let form = create_post_form ("toggle/" ^ cmd.name) (create_submit_button enabled) in
        [cmd.name; cmd.description; form] in
      let command_list = List.map row_of_command commands in
      create_table ["Name"; "Description"; "Status"] command_list

    let list_chats () =
      let row_of_chat chat =
        let open Api.Chat in
        let id = string_of_int chat.id
        and title = match chat.title with
          | Some title -> title
          | None -> "Unnamed chat"
        and leave = create_post_form ("leave/" ^ string_of_int chat.id)  (create_submit_button "Leave") in
        [id; title; leave] in
      let chat_list = List.map row_of_chat (get_chats ()) in
      create_table ["Chat ID"; "Chat title"; "Leave chat"] chat_list

    let show_uptime () =
      let diff = ODate.Unix.between (ODate.Unix.now ()) start_time in
      let fmt =
        "[%>:[%D:[#=1:tomorrow :[%s:[#>0:in ]]]]]" ^
        "[%Y:[#>0:# year[#>1:s] ][#=0:" ^
        "[%M:[#>0:# month[#>1:s] ][#=0:" ^
        "[%D:[#>1:# day[#>1:s] ][#=0:" ^
        "[%h:[#>0:# hour[#>1:s] ][#=0:" ^
        "[%m:[#>0:# minute[#>1:s] ][#=0:" ^
        "[%s:[#>0:# second[#>1:s] :just now ]" ^
        "]]]]]]]]]]]" in
      let printer = match ODuration.To.generate_printer fmt with
        | Some printer -> printer
        | None -> ODuration.To.default_printer in
      let repr = ODuration.To.string printer diff in
      Printf.sprintf {|<h2>Uptime: %s</h2>|} repr

    let index = get "/" begin fun req ->
        let html = create_document username [create_header username; show_uptime (); list_commands (); list_chats ()] in
        `Html html |> respond'
      end

    let toggle = post "/toggle/:cmd" begin fun req ->
        let open Api.Command in
        let cmd = param req "cmd" in
        List.iter (fun c -> if c.name = cmd then c.enabled <- not c.enabled) commands;
        redirect' (Uri.of_string "/")
      end

    let leave = post "/leave/:chat" begin fun req ->
        let chat_id = int_of_string @@ param req "chat" in
        ignore @@ leave_chat ~chat_id;
        begin match Lwt_main.run @@ get_chat ~chat_id with
          | Api.Result.Success chat -> remove_chat chat
          | Api.Result.Failure _ -> ()
        end;
        redirect' (Uri.of_string "/")
      end
  end

  let run ?(log=true) () =
    let open Lwt in
    let process = function
      | Api.Result.Success _ -> return ()
      | Api.Result.Failure e ->
        if log && e <> "Could not get head" then (* Ignore spam *)
          Lwt_io.printl e
        else return () in
    let app = App.empty |> Web.index |> Web.toggle |> Web.leave in
    begin match App.run_command' app with
      | `Ok _ | `Not_running -> print_endline "Successfully started Opium server!"
      | `Error -> print_endline "Couldn't initialize Opium server, dashboard will not start!"
    end;
    let rec loop () =
      pop_update ~run_cmds:true () >>= process >>= loop in
    while true do (* Recover from errors if an exception is thrown *)
      try Lwt_main.run (App.start app <&> loop ())
      with _ -> ()
    done;
    save_chats ~chats:(!chats)
end
