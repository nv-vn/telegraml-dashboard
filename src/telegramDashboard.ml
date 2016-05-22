open Telegram
open Batteries
open Opium.Std

module MkDashboard (B : Api.BOT) = struct
  module StringSet = Set.Make (struct
      open Api.Chat

      type t = chat

      let compare {id=id1} {id=id2} = Int.compare id1 id2
    end)

  let chats = ref StringSet.empty

  let get_chats () = StringSet.elements !chats

  include Api.Mk (struct
      include B

      let new_chat_member chat member =
        let open Api.User in
        if member.username = B.command_postfix then (* Same username *)
          chats := StringSet.add chat !chats
        else ();
        B.new_chat_member chat member

      let left_chat_member chat member =
        let open Api.User in
        if member.username = B.command_postfix then (* Same username *)
          chats := StringSet.remove chat !chats
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
          | None -> "Unnamed chat" in
        [id; title] in
      let chat_list = List.map row_of_chat (get_chats ()) in
      create_table ["Chat ID"; "Chat title"] chat_list

    let index = get "/" begin fun req ->
        let html = create_document username [list_commands (); list_chats ()] in
        `Html html |> respond'
      end

    let toggle = post "/toggle/:cmd" begin fun req ->
        let open Api.Command in
        let cmd = param req "cmd" in
        List.iter (fun c -> if c.name = cmd then c.enabled <- not c.enabled) commands;
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
    let app = App.empty |> Web.index |> Web.toggle in
    begin match App.run_command' app with
      | `Ok _ | `Not_running -> print_endline "Successfully started Opium server!"
      | `Error -> print_endline "Couldn't initialize Opium server, dashboard will not start!"
    end;
    let rec loop () =
      pop_update ~run_cmds:true () >>= process >>= loop in
    while true do (* Recover from errors if an exception is thrown *)
      try Lwt_main.run (App.start app <&> loop ())
      with _ -> ()
    done
end
