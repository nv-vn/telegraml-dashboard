# telegraml-dashboard
A set of extensions for TelegraML for automatically generating a web dashboard for your bot

## Features

* Default "run" function for bots
* Compatible with normal TelegraML interface
* Automatically generate a web interface for your bot, including
  + Viewing bot info/stats (username, uptime, latency, etc.)
  + Toggling (enabling/disabling) commands

## Porting TelegraML bots

In order to port a bot from standard TelegraML to TelegraML-dashboard, you first need to add the 
ocamlfind package `telegraml-dashboard` to your build system. Then, add the following line to your code:

```ocaml
open TelegramDashboard
```

Next, you need to switch from using the normal `Api.Mk` functor to using `MkDashboard` instead. The 
`Api.BOT` that you pass to it can remain 100% the same and all calls into to the resulting module should 
remain unaffected by the change.

Finally, you need to replace your main function with one that will start the Opium server up. A default 
function for this is exposed by the generated module from `MkDashboard`:

```ocaml
val run : ?log:bool -> unit -> unit
```

The `?log` parameter will allow you to enable or disable logging API errors to stdout.
