open Batteries
open Yojson.Safe
open Gensqlite_tools
open Telegram.Api.Chat

let prepare_chat {id; chat_type; title; username; first_name; last_name} =
  let open TelegramUtil in
  let chat_type' = match chat_type with
    | Private -> "private"
    | Group -> "group"
    | Supergroup -> "supergroup"
    | Channel -> "channel" in
  `Assoc (["id", `Int id;
           "type", `String chat_type'] +? ("title", this_string <$> title)
                                       +? ("username", this_string <$> username)
                                       +? ("first_name", this_string <$> first_name)
                                       +? ("last_name", this_string <$> last_name))
  |> Yojson.Safe.to_string

let init_database () =
  if Sys.file_exists "dashboard.db" then
    Sqlite3.db_open "dashboard.db"
  else begin
    File.write_lines "dashboard.db" (BatEnum.empty ());
    let db = Sqlite3.db_open "dashboard.db" in
    let (_, create) = [%gensqlite db "CREATE TABLE chats (chat_info STRING UNIQUE NOT NULL)"] in
    ignore @@ create ();
    db
  end

let db = init_database ()

let (_, add_chat)  = [%gensqlite db "INSERT INTO chats (chat_info) VALUES (%s{chat_info})"]
let (_, get_chats) = [%gensqlite db "SELECT @s{chat_info} FROM chats"]

