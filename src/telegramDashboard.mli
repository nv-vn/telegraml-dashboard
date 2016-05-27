module MkDashboard : functor (B : Telegram.Api.BOT) -> sig
  val get_chats : unit -> Telegram.Api.Chat.chat list

  include Telegram.Api.TELEGRAM_BOT

  module Web : sig
    val username : string
    val index : Opium.App.builder
    val toggle : Opium.App.builder
  end
end
