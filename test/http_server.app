{application, http_server,
 [
  {description, "Cowboy Basic Server."},
  {vsn, "0.1"},
  {applications,
   [kernel,
    stdlib,
    cowboy
   ]},
  {modules, []},
  {mod, {http_server, []}},
  {start_phases, [{start_cowboy_http, []}]}
 ]
}.
