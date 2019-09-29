defmodule MitraCrm do

  alias MitraCrm
  @moduledoc """
  Documentation for MitraCrm.
  """

  @doc """
  Hello world.

  ## Examples

      iex> MitraCrm.hello()
      :world

  """

  
  def start(name, persistence_uri, persistence_type) do
    opts = %{persistence_uri: persistence_uri, persistence_type: persistence_type}
    start(name, opts)
  end

  def start(name, opts) when is_map(opts) do
    with {:ok, persistence_uri} <- Map.get(opts, :persistence_uri),
    {:ok, persistence_type} <- Map.get(opts, :persistence_type), 
    {:ok, pid} <- MitraCrm.Crm.start_link(name, persistence_uri, persistence_type) do
      pid
    else 
      err -> err
    end
  end



  def load(pid) do
    MitraCrm.Crm.load_state_proc(pid)
  end

  def save(pid) do
    MitraCrm.Crm.persist_state_pid(pid)
  end

  def add_stakeholder(pid, stakeholder_opts_or_stakeholder_name) do
    MitraCrm.Crm.add_stakeholder(pid, stakeholder_opts_or_stakeholder_name)
  end

  def status(pid) do
    with {n, ng_sk} <- MitraCrm.Crm.get_neglected_stakeholders(pid, 7, 7),
      upcoming <- MitraCrm.Crm.get_upcoming_dates(pid),
      neglected_str <- pretty_print_stakeholders(ng_sk),
      upcoming_str <- pretty_print_dates(upcoming) do
        IO.puts(neglected_preamble())
        IO.puts(neglected_str)
        IO.puts(upcoming_preamble())
        IO.puts(upcoming_str)
      else 
        err -> err
      end 
  end

  defp neglected_preamble() do
    """
    ============================
    = Neglected Stakeholders   =
    ============================
    """
  end

  defp upcoming_preamble() do
    """
    ============================
    = Upcoming Dates           =
    ============================
    """
  end

  defp pretty_print_stakeholders(stakeholders) do
    Enum.map(stakeholders, fn x -> pretty_print_stakeholder(x) end)
    |> Enum.sort
    |> Enum.reduce("", fn x, acc -> x <> acc end )
  end

  defp pretty_print_stakeholder(stakeholder) do
    with name <- Map.get(stakeholder, :name) do
    "Name: #{name.given_name} #{name.family_name}\n"
    else 
      err -> err   
    end
  end

  defp pretty_print_dates(dates) do
    with engagements <- Map.get(dates, :engagements),
    dts <- Map.get(dates, :important_dates),
    e <- Enum.reduce(engagements, "", fn(x, acc) -> pretty_print_date(x) <> acc end),
    d <- Enum.reduce(dts, "", fn(x, acc) -> pretty_print_date(x) <> acc end) do
      """
      Engagements:
      #{e}

      Dates:
      #{d}
      """
    else 
      err -> err  
    end 
  end

  defp pretty_print_date(date) do
    cond do
      Map.has_key?(date, :engagements) -> 
        with engagements <- Map.get(date, :engagements),
            name <- Map.get(date, :name) do
            engs = Enum.reduce(engagements, "", fn(x, acc) -> "#{x.name} (#{Date.to_iso8601(x.due_date)})\n" <> acc end )
            stakeholder = "Name: #{name.given_name} #{name.family_name}\n"
            stakeholder <> engs
          else  
            err -> err  
          end
      Map.has_key?(date, :dates) -> 
        with dates <- Map.get(date, :dates),
            name <- Map.get(date, :name) do
            date = Enum.reduce(dates, "", fn(x, acc) -> "#{x.description} (#{Date.to_iso8601(x.date)})\n" <> acc end )
            stakeholder = "Name: #{name.given_name} #{name.family_name}\n"
            stakeholder <> date
          else  
            err -> err  
          end
      true -> "error"
    end
  end

end
