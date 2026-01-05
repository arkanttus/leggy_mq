defmodule DemoRepo do
  use Leggy, hostname: "localhost", username: "guest", password: "guest", pool_size: 2
end
