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

    let list_commands () =
      let string_of_command cmd =
        let open Api.Command in
        let enabled = match cmd.enabled with
          | true -> "Enabled"
          | false -> "Disabled" in
        let button = "<input type=\"submit\" value=\"" ^ enabled ^ "\"/>" in
        let form = "<form action=\"toggle/" ^ cmd.name ^ "\" method=\"POST\">" ^ button ^ "</form>" in
        "<tr><td>/" ^ cmd.name ^ "</td><td>" ^ cmd.description ^ "</td><td>" ^ form ^ "</td></tr>" in
      let command_table = List.map string_of_command commands |> String.concat "" in
      "<table><tr><td>Name</td><td>Description</td><td>Status</td></tr>" ^ command_table ^ "</table>"

    let list_chats () =
      let string_of_chat chat =
        let open Api.Chat in
        let id = string_of_int chat.id
        and title = match chat.title with
          | Some title -> title
          | None -> "Unnamed chat" in
        "<tr><td>" ^ id ^ "</td><td>" ^ title ^ "</td></tr>" in
      let chat_table = List.map string_of_chat (get_chats ()) |> String.concat "" in
      "<table><tr><td>Chat ID</td><td>Chat title</td></tr>" ^ chat_table ^ "</table>"

    let index = get "/" begin fun req ->
        let html =
          Printf.sprintf
            "<html><head><title>TelegraML Dashboard</title></head><body>%s\n%s\n%s</body></html>"
            username
            (list_commands ())
            (list_chats ()) in
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
