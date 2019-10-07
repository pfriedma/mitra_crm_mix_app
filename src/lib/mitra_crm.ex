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
  
  def start([name,id]) do
    {:ok, app} = MitraCrm.Application.start_crm([name, id])
    kernel_loop(id)
  end

  def kernel_loop(id) do
    pid = get_pid(id)
    load(pid)
    shell(pid)
    kernel_loop(id)
  end

  def get_pid(id) do
    :global.whereis_name("MitraCrm.#{id}")
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
    if is_map(stakeholder.attributes) do
       Map.to_list(stakeholder.attributes)
       |> Enum.each(fn {k,v} -> IO.puts("#{k}: #{v}") end)
    else 
      IO.puts("")
    end
    IO.puts("\nConcerns:")
    IO.inspect(stakeholder.concerns)
    IO.puts("\n")
  end

  def shell(pid) do
    IO.puts("Mitra")
    with opts <- [{"Status Dashboard", fn x-> status(x) end},
            {"Manage Stakeholders", fn x-> stk_shell(x) end},
          {"Exit", true}],
    {:ok, {d,f}} <- do_selection_from_list(opts, 
      fn x -> x end, fn {k,{l,v}} -> IO.puts("#{k}: #{l}") end) do
        if f == true, do: true, else: f.(pid)
      else 
        err -> err  
      end
  end

  def stk_shell(pid) do
    with stakeholders <- select_stakeholder(pid),
      Enum.each(stakeholders, fn {k, v} -> IO.puts("#{k}: #{v.gn} #{v.sn}") end),
      sel <- String.trim(IO.gets("Select (0 to add new, x to abort):")) do
        if sel == "x" do
          true
        else
          with true <- String.length(String.trim(sel)) > 0,
            index <- String.to_integer(String.strip(sel)),
            stk <- Map.get(stakeholders, index)
            do
              if index == 0, do: perform_add_stakeholder(pid), else: perform_stakeholder_action(pid, stk.uuid)
              save(pid)
              stk_shell(pid)
            else
              _ -> IO.puts("invalid slection")
              save(pid)
              stk_shell(pid)
            end
          end
        else 
          err -> err 
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
        7: Mod Engagemeent
        8: Mod Concern 
        0: Return
        """
      ) do
        case String.to_integer(String.trim(IO.gets("Action:"))) do
          1 -> do_add_engagement(pid, stakeholder)
          2 -> do_add_date(pid, stakeholder)
          3 -> do_add_concern(pid, stakeholder)
          4 -> do_add_attribute(pid, stakeholder)
          5 -> pretty_print_stakeholder_details(stakeholder)
          6 -> delete_stakeholder(pid, stakeholder)
          7 -> do_mod_engagement(pid, stakeholder)
          8 -> do_mod_concern(pid, stakeholder)
          0 -> true
          _ -> perform_stakeholder_action(pid, uuid)
        end
      end
  end

  def do_mod_engagement(pid, stakeholder) do 
    with {:ok, selected_engagement} <- do_select_engagement(stakeholder.timeline),
    states <- [:open, :in_progress, :complete, :deferred, :canceled],
    results <- [:success, :failure]   do
      case String.to_integer(prompt(
        """
        #{selected_engagement.name}
        0: Abort
        1: Defer 
        2: Add Notes
        3: Update State
        4: Resolve
        """
        )) do
          0 -> true
          1 -> delay = String.to_integer(prompt("Defer by how many days?:"))
              MitraCrm.Crm.defer_engagement(pid, stakeholder, selected_engagement, delay)
          2 -> note = prompt("Add Note:")
              MitraCrm.Crm.add_note_to_engagement(pid, stakeholder, selected_engagement, note)
          3 ->{:ok, state} = do_selection_from_list(states, &(&1), fn {k,v} -> IO.puts("#{k}: #{v}") end) 
                MitraCrm.Crm.set_engagement_state(pid, stakeholder, selected_engagement, state)
              
          4 -> {:ok, result} = do_selection_from_list(results, &(&1), fn {k,v} -> IO.puts("#{k}: #{v}") end)
              MitraCrm.Crm.complete_engagement_w_status(pid, stakeholder, selected_engagement, result)
          _ -> true
        end 
    end
  end

  defp do_select_engagement(engagements) do
    with filtered_engagments <- Enum.reject(engagements, fn x -> 
        (x.state == :deferred or x.state == :complete or x.state == :canceled) end),
      {:ok, selection} <- do_selection_from_list(
      filtered_engagments, 
      fn x -> x end,
      fn {k,v} -> IO.puts(
        """
        #{k}:
        Name: #{v.name}
        Due Date: #{Date.to_iso8601(v.due_date)}
        Notes: #{v.notes}
        Result: #{v.result}
        State: #{v.state}
        Type: #{v.engagement_type.engagement_type}
        """) end ) do
          {:ok, selection}
        else 
          _ -> :error 
        end
  end

  def do_mod_concern(pid, stakeholder) do
    with concerns <- stakeholder.concerns,
       selected_concern <- do_select_concern(concerns),
       false <- is_nil(selected_concern), 
        updated_concern <- do_mod_concern_menu(selected_concern) do
          MitraCrm.Crm.mod_stakeholder_concern(pid, stakeholder, selected_concern, updated_concern)
          else 
            err -> err  
          end
  end

  defp do_mod_concern_menu(concern) do
    with sel <- String.to_integer(prompt(
      """
      Updating #{concern.name}
      0 To Abort
      1: Resolve Concern
      2: Update Importance
      9: Delete Concern
      """
    )) do
      case sel do
        1 -> if confirm("Resolved (y/n)? ") do
          Map.replace!(concern, :resolved, true)
        end
        2 -> new_importence = String.to_integer(prompt("New Importance (0-9):"))
             if 0 < new_importence and new_importence> 9 do
               Map.replace!(concern, :importance, new_importence)
             else 
              IO.puts("invalid")
              concern
             end
        9 -> nil
        _ -> concern
        true -> concern
      end
    end
    
  end


  defp do_select_concern(concerns) do
    with {:ok, selection} <- do_selection_from_list(
      concerns, 
      fn x -> x end,
      fn {k,v} -> IO.puts(
        """
        #{k}:
        Name: #{v.name}
        Description: #{v.description}
        Importance: #{v.importance}
        Resolved: #{v.resolved}
        Date Added: #{Date.to_iso8601(v.date_added)}
        """) end
      ) do
          selection
    else 
          _ -> nil 
    end
    
  end 
  defp do_selection_from_list(list, map_fn, disp_fn) do
    sel_map = select_from_list(list, map_fn)
    sel_map
    |> Enum.each(disp_fn)
    sel = String.to_integer(prompt("Selection (0 to abort):"))
    if sel > 0 do
      Map.fetch(sel_map, sel)
    else 
      nil
    end
  end



  defp select_from_list(list, attribute_map) do
    Stream.with_index(list, 1) |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, attribute_map.(v)) end)

  end

  def do_add_date(pid, stakeholder) do
    with date <- prompt("Date (ISO):"),
      description <- prompt("Description:"),
      reminder <- String.to_integer(prompt("Reminder (days):")),
      annual <- String.to_existing_atom(prompt("Annual date (true/false):")) do
        MitraCrm.Crm.add_stakeholder_date(pid, stakeholder, date, description, reminder, annual)
      else  
        err -> err  
      end 
  end

  def do_add_concern(pid, stakeholder) do
    with name <- prompt("Name of Concern:"),
      desc <- prompt("Concern Description:"),
      importance <- String.to_integer(prompt("Concern Importance (0-9):")) do
        MitraCrm.Crm.add_stakeholder_concern(pid, stakeholder.meta.uuid, name, desc, importance)
      else
        err -> err  
      end
  end

  def do_add_attribute(pid, stakeholder) do
    with attribute <- prompt("Attribute Name:"), 
      value <- prompt("Attribute Value:") do
        IO.puts("Creating:\n#{attribute}:#{value}\n")
        confirm(MitraCrm.Crm.update_stakeholder_attributes(pid, stakeholder.meta.uuid, attribute, value))
      else
        err -> err  
      end
  end
  def do_add_engagement(pid, stakeholder) do
    with engagement_name <- strip_val(IO.gets("Engagement Name:")),
      engagement_type <- strip_val(IO.gets("Engagement Type:")),
      due_date <- strip_val(IO.gets("Due Date:")) do
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
    with given_name <- strip_val(IO.gets("Given Name: ")),
      family_name <- strip_val(IO.gets("Family Name: ")),
      middle_initial <- strip_val(IO.gets("Middle Initial:")),
      prefix <- strip_val(IO.gets("Prefix:")), 
      suffix <- strip_val(IO.gets("Suffix:")) do
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

  defp strip_val(x) do
    if String.length(String.trim(x)) > 0, do: String.trim(x), else: nil
  end

  defp prompt(string) do
    with val <- IO.gets(string) do
      strip_val(val)
    else 
      err -> err  
    end
  end

  defp confirm(fun) do
    case prompt("Proceed? (y/n)") do
      "y" -> fun 
      _ -> IO.puts("Aborting")
    end
  end

end
