open Telegram
open Dashboard
open Opium.Std

module Bot = MkDashboard (struct
    include BotDefaults

    let token = [%blob "../bot.token"]

    let commands =
      let open Api.Command in
      [{name="test"; description="Test command"; enabled=false; run = fun _ -> print_endline "testing"; Nothing}]
  end)

let () = Bot.run ()
