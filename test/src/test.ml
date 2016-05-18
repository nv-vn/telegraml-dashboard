open Telegram
open Opium.Std
open TelegramDashboard

module Bot = MkDashboard (struct
    include BotDefaults

    let token = [%blob "../bot.token"]

    let commands =
      let open Api.Command in
      let open Api.Message in
      let test {chat} = SendMessage (Api.Chat.(chat.id), "Hello", false, None, None) in
      [{name="test"; description="Test command"; enabled=true; run = test}]
  end)

let () = Bot.run ()
