defmodule EmailSchema do
  use Leggy.Schema

  schema "exchange_test", "queue_test" do
    field(:user, :string)
    field(:ttl, :integer)
    field(:valid?, :boolean)
    field(:requested_at, :datetime)
  end
end
