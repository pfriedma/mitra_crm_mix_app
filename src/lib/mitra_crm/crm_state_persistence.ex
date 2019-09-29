defmodule MitraCrm.CrmStatepersistence do
  @moduledoc """
  This is a persistence server for CRM processes, 
  handles saving and retreiving a CRM processes state

  """
  use GenServer
  alias MitraCrm.{Stakeholder, Stakeholderpersistence, Engagement, EngagementType, Crm}
  @derive [Poison.Encoder, Poison.Decoder]

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init([]) do
    {:ok, %{}}
  end

  def init([:redis, redis_server, crm_id]) do
    {:ok, conn} = Redix.start_link(redis_server, name: :redix)
    {:ok, %{persistence_redisclient: conn, crm_id: crm_id}}
  end

  def init([:file, filename, crm_id]) do
    {:ok, %{persistence_filename: filename, crm_id: crm_id}}
  end
  @doc """
  Tells the persistence process specified by `pid` to load an individual persistence file (JSON encoded) from `filename`

  Returns `{:ok, state}`.

  """
  def load(pid, filename) do
    GenServer.call(pid, {:load, filename})
  end

  def load(pid) do
    GenServer.call(pid, :load_using_state)
  end

  @doc """
  Tells the persistence process specified by `pid` to load the persistence  file (JSON encoded) from `filename`
  and returns the state whoose %{user: %{id: }} map has the value specified by `id`.

  Returns `{:ok, state}`. if state found
  `{:error, :not_found}` otherwise.

  """
  def load(pid, filename, id) do
    GenServer.call(pid, {:load, filename, id})
  end

  @doc """
  Tells the persistence process specified by `pid` to write out state `data` to `filename` as JSON.
  Appends to file. 

  Returns `{:ok}
  """
  def write(pid, filename, data) do
    GenServer.call(pid, {:write, filename, data})
  end

  def write(pid, data) do 
    GenServer.call(pid, {:write_proc, data})
  end

  @doc """
  Genserver handler for load
  Loads `filename` and returns the state whoose state contains the id %{user: %{:id}}
  """
  def handle_call({:load, filename, id}, _from, state) do
    with {:ok, crm_state} <- load_state_from_file(filename, id) do
      {:reply, {:ok, crm_state}, state}
    else
      err -> {:reply, err, state}
    end
  end

  def handle_call({:load_redis, redis_server, id}, _from, state) do
    with {:ok, crm_state} <- load_state_from_redis(redis_server, id) do
      {:reply, {:ok, crm_state}, state}
    else
      err -> {:reply, err, state}
    end
  end

  def handle_call(:load_using_state, _from, state) do
      with {:ok, {kind, filename, id}} <- get_persistence_params(state),
      {:ok, crm_state} <- load_state(kind, filename, id) do
        {:reply, {:ok, crm_state}, state}
      else
        err -> {:reply, err, state}
      end

  end

  def handle_call({:update_persistence_params, {filename, crm_id, :file}}, _from, state) do
    newstate = state
    |> Map.put(:filename, filename)
    |> Map.put(:crm_id, crm_id)
    {:reply, :ok, newstate}
  end

  def handle_call(:get_persistence_params, _from, state) do
    {:reply, get_persistence_params(state), state}
  end

  @doc """
  Genserver handler forwrite
  Writes `data` to `filename`.


  """
  def handle_call({:write, filename, data}, _from, state) do
    with :ok <- write_state_to_file(filename, data) do
      {:reply, {:ok}, state}
    else
      err -> err
    end
  end

  def handle_call({:write_proc, data}, _from, state) do
    with {:ok, {kind, filename, id}} <- get_persistence_params(state),
    :ok <- write_state(kind, filename, data) do
      {:reply, {:ok}, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def load_state_from_file!(filename) do
    {:ok, state} = load_state_from_file(filename)
    state
  end

  def load_state_from_file!(filename, id) do
    with {:ok, state} <- load_state_from_file(filename, id) do
      state
    else
      err -> err
    end
  end

  @doc """
  Loads the `filename` as a stream and returns the result of calling Crm.from_json() on it

  """
  def load_state_from_file(filename) do
    with stream <- File.stream!(filename, [:read], :line),
         ops <- Stream.map(stream, fn x -> Crm.from_json!(x) end),
         state <- Enum.to_list(ops) do
      {:ok, state}
    else
      err -> err
    end
  end


  @doc """
  Loads in the persistence from redis with the specified proc id

  Returns {:ok, state}.
  """ 
  def load_state_from_redis(redis_server, id) do
    with  {:ok, state_json} <- Redix.command(redis_server, ["GET", id]),
      {:ok, state} <- Crm.from_json(state_json)   
    do
      {:ok, state}
    else
      err -> err 
    end
  end






  @doc """
  Loads in the `filename` and filters the lines to where %{user: %{id: x}} = id
  Does not currently de-duplicate.

  Returns {:ok, state}.
  """ 
  def load_state_from_file(filename, id) do
    with stream <- File.stream!(filename, [:read], :line),
         ops <- Stream.map(stream, fn x -> Crm.from_json!(x) end),
         filtered <- Stream.filter(ops, fn x -> Map.get(Map.get(x, :user), :id) == id end),
         state <- Enum.to_list(filtered) do
      if length(state) > 0 do
        [s] = state
        {:ok, s}
      else
        {:error, :not_found}
      end
    else
      err -> err
    end
  end

  def replace_in_file(filename, state) do
    with {:ok, state_user} <- Map.fetch(state, :user),
         {:ok, id} <- Map.fetch(state_user, :id), 
         {:ok, json} <- Crm.to_json(state),
         stream <- File.stream!(filename, [:read, :write], :line),
         filtered_stream <- stream 
         |> Stream.map(fn x -> Crm.from_json!(x) end)
         |> Stream.reject(fn x -> Map.get(Map.get(x, :user), :id) == id end)
         |> Stream.map(fn x -> Crm.to_json!(x) end)
         do
            Stream.into([json| Enum.to_list(filtered_stream)], stream, fn x -> x <> "\n" end)
            |> Stream.run()
         else
          err -> err
         end
    end

  @doc """
  Writes the `state` of a Crm process to `filename` as JSON encoded data.

  returns {:ok} or `err`.
  """

  def write_state_to_file(filename, state) do
    #with stream <- File.stream!(filename, [:append], :line) do
     # Stream.into([state], stream, fn x -> Crm.to_json!(x) <> "\n" end)
    #  |> Stream.run()
    #else
    #  err -> err
    #end
    replace_in_file(filename, state)
  end

  def write_state_to_redis(redis_server, state) do
    with {:ok, state_user} <- Map.fetch(state, :user),
    {:ok, id} <- Map.fetch(state_user, :id), 
    {:ok, json} <- Crm.to_json(state),
    {:ok, "OK"} <- Redix.command(redis_server, ["SET", id, json]) do
      :ok
    else
      err -> err 
    end
  end

  defp get_persistence_params(state) do 
    cond do
      Map.has_key?(state, :persistence_filename) ->
        with {:ok, crm_id} <- Map.fetch(state, :crm_id), 
        {:ok, filename} <- Map.fetch(state, :persistence_filename) do
          {:ok, {:file, filename, crm_id}}
        else
          err -> {:error, {:persistence_not_found, err}}
        end
      Map.has_key?(state, :persistence_redisclient) ->
        with {:ok, crm_id} <- Map.fetch(state, :crm_id), 
        {:ok, redis_server} <- Map.fetch(state, :persistence_redisclient) do
          {:ok, {:redis, redis_server, crm_id}}
        else
          err -> {:error, {:persistence_not_found, err}}
        end
      true -> 
        {:error, {:persistence_not_found, nil}}
    end
  end



  defp load_state(:redis, redis_server, id) do
    load_state_from_redis(redis_server, id)
  end
  defp load_state(:file, filename, id) do
    load_state_from_file(filename, id)
  end

  defp write_state(:file, filename, id) do
    write_state_to_file(filename, id) 
  end
  defp write_state(:redis, redis_server, id) do
    write_state_to_redis(redis_server, id)
  end

end