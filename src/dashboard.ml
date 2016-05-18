open Telegram
open Batteries
open Opium.Std

module MkDashboard (B : Api.BOT) = struct
  include Api.Mk (B)

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

    let commands =
      let string_of_command cmd =
        let open Api.Command in
        let enabled = match cmd.enabled with
          | true -> "Enabled"
          | false -> "Disabled" in
        "<tr><td>/" ^ cmd.name ^ "</td><td>" ^ cmd.description ^ "</td><td>" ^ enabled ^ "</td></tr>" in
      let command_table = List.map string_of_command B.commands |> String.concat "" in
      "<table><tr><td>Name</td><td>Description</td><td>Status</td></tr>" ^ command_table ^ "</table>"

    let index = get "/" begin fun req ->
        let html =
          Printf.sprintf
            "<html><head><title>TelegraML Dashboard</title></head><body>%s\n%s</body></html>"
            username
            commands in
        `Html html |> respond'
      end
  end
end
