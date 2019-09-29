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
    MitraCrm.save(pid)
  end

  def add_engagement(pid, stakeholder, engagement_name, type_name, due_date ) do
    MitraCrm.Crm.add_new_engagement(pid, stakeholder, engagement_name, type_name, due_date)
    MitraCrm.save(pid)
  end

  def list_engagements(pid, stakeholder_uuid) do 
    with {:ok, stakaholder} <- MitraCrm.Crm.get_stakeholder_by_uuid(pid, stakeholder_uuid) do
      ""
    end
  end

  def select_stakeholder(pid) do
    with stakeholders <- MitraCrm.Crm.get_stakeholders(pid) do
      Stream.with_index(stakeholders, 1) |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, %{uuid: v.meta.uuid, gn: v.name.given_name, sn: v.name.family_name}) end)
      
    end
  end


  def list_stakeholders(pid) do
    with stakeholders <- MitraCrm.Crm.get_stakeholders(pid) do
      IO.puts(
        """

        Stakeholder   -- UID
        ----------------------------------------- 
        """
      )
      IO.puts(Enum.reduce(stakeholders, "", fn(x,acc) -> 
        "#{x.name.given_name} #{x.name.family_name} -- #{x.meta.uuid}\n" <> acc end ))
    end
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

  def pretty_print_stakeholder_details(stakeholder) do
    IO.puts("\nRelationship:")
    pretty_print_stakeholder_relationship(stakeholder)
    IO.puts("\nAttributes:")
    if is_map(stakeholder.attributes), do: stakeholder.attributes, else: %{}
    |>  Map.to_list 
    |> Enum.each(fn {k,v} -> IO.puts("#{k}: #{v}") end)

  end

  def shell(pid) do
    save(pid)
    with stakeholders <- select_stakeholder(pid),
      Enum.each(stakeholders, fn {k, v} -> IO.puts("#{k}: #{v.gn} #{v.sn}") end),
      sel <- IO.gets("Select (0 to add new): "),
      true <- String.length(String.trim(sel)) > 0,
      index <- String.to_integer(String.strip(sel)),
      stk <- Map.get(stakeholders, index)
      do
        if index == 0, do: perform_add_stakeholder(pid), else: perform_stakeholder_action(pid, stk.uuid)
      else
        _ -> IO.puts("invalid slection")
        save(pid)
        shell(pid)
      end
    
  end

  def perform_stakeholder_action(pid, uuid) do
      with {:ok, stakeholder} <- MitraCrm.Crm.get_stakeholder_by_uuid(pid, uuid),
      IO.puts(
        """
        #{pretty_print_stakeholder(stakeholder)}
        Actions: 
        1: Add Engagement
        2: Add Date
        3: Add Concern
        4: Add Attirbute
        5: Get Details
        6: Delete
        """
      ) do
        case String.to_integer(String.trim(IO.gets("Action:"))) do
          1 -> do_add_engagement(pid, stakeholder)
          5 -> pretty_print_stakeholder_details(stakeholder)
          6 -> delete_stakeholder(pid, stakeholder)
          _ -> ""
        end
      end
  end

  def do_add_engagement(pid, stakeholder) do
    strip_val = &(if String.length(String.trim(&1)) > 0, do: String.trim(&1), else: nil)
    with engagement_name <- strip_val.(IO.gets("Engagement Name:")),
      engagement_type <- strip_val.(IO.gets("Engagement Type:")),
      due_date <- strip_val.(IO.gets("Due Date:")) do
        MitraCrm.Crm.add_new_engagement(pid, stakeholder, engagement_name, engagement_type, due_date)
        MitraCrm.save(pid)
      else 
        err -> err  
      end
      
  end

  def delete_stakeholder(pid, stakeholder) do
    MitraCrm.Crm.delete_stakeholder(pid, stakeholder)
    shell(pid)
  end
  
  def perform_add_stakeholder(pid) do
    strip_val = &(if String.length(String.trim(&1)) > 0, do: String.trim(&1), else: nil)
    with given_name <- strip_val.(IO.gets("Given Name: ")),
      family_name <- strip_val.(IO.gets("Family Name: ")),
      middle_initial <- strip_val.(IO.gets("Middle Initial:")),
      prefix <- strip_val.(IO.gets("Prefix:")), 
      suffix <- strip_val.(IO.gets("Suffix:")) do
        args = [given_name: given_name, family_name: family_name, middle_initial: middle_initial, prefix: prefix, suffix: suffix]
        case String.trim(IO.gets("OK? (y/n/a)")) do 
          "y" -> MitraCrm.add_stakeholder(pid, args)
          "a" -> shell(pid)
          _ -> perform_add_stakeholder(pid)
        end
    end
    shell(pid)
  end

  defp pretty_print_stakeholder_relationship(stakeholder) do
    with relationship <- Map.get(stakeholder, :relationship),
      dimensions <- Map.keys(relationship) do
      Enum.filter(dimensions, fn x -> is_map(Map.get(relationship, x)) end)
      |> Enum.map(fn x -> 
        rel = Map.get(relationship, x)
        "#{x} - at #{rel.metric} #{if not rel.focused, do: "not "}focusing" end)
      |> Enum.each(fn x -> IO.puts(x) end)
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
