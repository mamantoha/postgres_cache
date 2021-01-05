require "./spec_helper"

describe Cache::PostgresStore do
  before_each do
    pg.exec(
      <<-SQL
        CREATE UNLOGGED TABLE #{table_name} (
          key text PRIMARY KEY,
          value text,
          expires_in interval NOT NULL,
          created_at timestamp NOT NULL
        )
      SQL
    )
  end

  after_each do
    pg.exec("DROP TABLE #{table_name}")
  end

  it "initialize" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    store.should be_a(Cache::Store(String, String))
  end

  it "write to cache first time" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    value = store.fetch("foo") { "bar" }
    value.should eq("bar")
  end

  it "fetch from cache" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    value = store.fetch("foo") { "bar" }
    value.should eq("bar")

    value = store.fetch("foo") { "baz" }
    value.should eq("bar")
  end

  it "don't fetch from cache if expired" do
    store = Cache::PostgresStore(String, String).new(1.seconds, pg)

    value = store.fetch("foo") { "bar" }
    value.should eq("bar")

    sleep 2

    value = store.fetch("foo") { "baz" }
    value.should eq("baz")
  end

  it "fetch with expires_in from cache" do
    store = Cache::PostgresStore(String, String).new(1.seconds, pg)

    value = store.fetch("foo", expires_in: 1.hours) { "bar" }
    value.should eq("bar")

    sleep 2

    value = store.fetch("foo") { "baz" }
    value.should eq("bar")
  end

  it "don't fetch with expires_in from cache if expires" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    value = store.fetch("foo", expires_in: 1.seconds) { "bar" }
    value.should eq("bar")

    sleep 2

    value = store.fetch("foo") { "baz" }
    value.should eq("baz")
  end

  it "write" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)
    store.write("foo", "bar", expires_in: 1.minute)

    value = store.fetch("foo") { "bar" }
    value.should eq("bar")
  end

  it "read" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)
    store.write("foo", "bar")

    value = store.read("foo")
    value.should eq("bar")
  end

  it "set a custom expires_in value for entry on write" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)
    store.write("foo", "bar", expires_in: 1.second)

    sleep 2

    value = store.read("foo")
    value.should eq(nil)
  end

  it "delete from cache" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    value = store.fetch("foo") { "bar" }
    value.should eq("bar")

    result = store.delete("foo")
    result.should eq(true)

    value = store.read("foo")
    value.should eq(nil)
    store.keys.should eq(Set(String).new)
  end

  it "deletes all items from the cache" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    value = store.fetch("foo") { "bar" }
    value.should eq("bar")

    store.clear

    value = store.read("foo")
    value.should eq(nil)
    store.keys.should be_empty
  end

  it "#exists?" do
    store = Cache::PostgresStore(String, String).new(12.hours, pg)

    store.write("foo", "bar")

    store.exists?("foo").should eq(true)
    store.exists?("foz").should eq(false)
  end

  it "#exists? expires" do
    store = Cache::PostgresStore(String, String).new(1.second, pg)

    store.write("foo", "bar")

    sleep 2

    store.exists?("foo").should eq(false)
  end
end

def pg
  # psql -c 'CREATE DATABASE postgres_store_test;' -U postgres
  DB.open("postgres://postgres@localhost/postgres_store_test")
end

def table_name
  "cache_entries"
end
