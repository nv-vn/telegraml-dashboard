open Telegram
open Dashboard
open Opium.Std

module Bot = MkDashboard (struct
    include BotDefaults

    let token = [%blob "../bot.token"]

    let commands =
      let open Api.Command in
      [{name="test"; description="Test command"; enabled=false; run = fun _ -> Nothing}]
  end)

let () = App.run_command (App.empty |> Bot.Web.index)
