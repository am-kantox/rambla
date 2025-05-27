defmodule Rambla.Test.Clickhouse do
  @moduledoc false
  @queries %{
    drop: "DROP TABLE events",
    create: """
    CREATE TABLE events
      (
        source_id UUID,
        timestamp DateTime64(9),
        message String
      )
      ENGINE = MergeTree
      PRIMARY KEY (source_id, timestamp)
    """,
    select: "SELECT * FROM events"
  }

  def query(query),
    do: Rambla.Services.Clickhouse.Conn.query(query)

  def drop_table_events, do: query(@queries.drop)
  def create_table_events, do: query(@queries.create)

  def prepare do
    drop_table_events()
    create_table_events()
  end

  def select_from_table_events do
    Rambla.Services.Clickhouse.Conn.select(@queries.select)
  end
end
