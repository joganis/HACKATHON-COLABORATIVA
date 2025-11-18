import Config

config :logger,
  level: :info,
  format: "$time [$level] $message\n"

import_config "#{config_env()}.exs"
