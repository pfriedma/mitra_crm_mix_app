defmodule MitraCrm.Crm do
  @moduledoc """
  A process for handling a CRM activity. 
  Manages stakeholders and their associated data. 
  """

  use GenServer

  alias MitraCrm.{
    StakeholderName,
    StakeholderMetadata,
    Stakeholder,
    Stakeholderpersistence,
    Engagement,
    EngagementType,
    Crm,
    StakeholderConcern,
    StakeholderDate,
    StakeholderRelationship,
    StakeholderRelationshipValue
  }

  @derive [{Poison.Encoder, except: [:persistence_pid]}, Poison.Decoder]
  defstruct user: %{id: 0},
            stakeholders: [%Stakeholder{}],
            engagement_types: [%EngagementType{}],
            persistence_pid: nil

  @doc """
  Starts up a Crm process specified by `id`, which should probably map to something like ther user's id.

  returns {`:ok`, `pid`}
  """
  def child_spec([id, p_uri, p_state]) do
    %{
        id: Crm,
        start: {__MODULE__, :start_link, [id, p_uri, p_state]},
        restart: :permanent,
        type: :worker
      }
  end

  def start_link(id) do
    IO.puts("No config")
    GenServer.start_link(__MODULE__, [id, []], [])
  end

  def start_link(id, redis_server, :redis) do
    GenServer.start_link(__MODULE__, [id, [:redis, redis_server, id]], [name: {:via, :global, "MitraCrm.#{id}"}])
  end

  def start_link(id, filename, :file) do
    GenServer.start_link(__MODULE__, [id, [:file, filename, id]], [name: {:via, :global, "MitraCrm.#{id}"}])
  end

  def init([id, opts]) when is_list(opts) do
    Process.flag(:trap_exit, true)
    user = %{id: id}
    stakeholders = []
    {:ok, engagement_types} = EngagementType.get_default_engaement_types()
    {:ok, persistence_pid} = MitraCrm.CrmStatepersistence.start_link(opts)

    {:ok,
     %{
       user: user,
       stakeholders: stakeholders,
       engagement_types: engagement_types,
       persistence_pid: persistence_pid
     }}
  end

  @doc """
  loads stakeholders as JSON data from `filename`.

  returns {:ok, stakeholders}.
  """
  def load_stakeholders_from_file(pid, filename) when is_binary(filename) do
    GenServer.call(pid, {:load_stakeholders_from_file, filename})
  end

  @doc """
  Loads stakeholders as JSON data from `filename`.
  Returns `{:ok,}`.

  """
  def load_stakeholders_from_file!(pid, filename) when is_binary(filename) do
    GenServer.cast(pid, {:load_stakeholders_from_file, filename})
  end

  @doc """
  Teslls the crm process of `pid` to load state from `filename`.

  returns `{:ok}`.
  """
  def load_state_file!(pid, filename) when is_binary(filename) do
    GenServer.cast(pid, {:load_state_file, filename})
  end

  @doc """
  Teslls the crm process of `pid` to load state from `filename`.

  returns `{:ok, state}`.
  """
  def load_state_file(pid, filename) when is_binary(filename) do
    GenServer.call(pid, {:load_state_file, filename})
  end

  def load_state_proc(pid) do
    GenServer.call(pid, :load_state_proc)
  end

  @doc """
  Tells the Crm proc at `pid` to write its state to `filename`.

  returns `{:ok}`.
  """
  def persist_state(pid, filename) when is_binary(filename) do
    GenServer.call(pid, {:persist_state, filename})
  end

  def persist_state_pid(pid) do
    GenServer.call(pid, :persist_state_proc)
  end

  @doc """
  Get the stakeholders from the CRM processes at `pid`.

  returns `{:ok, [%Stakeholders{}]}
  """
  def get_stakeholders(pid) do
    GenServer.call(pid, :get_stakeholders)
  end

  @doc """
  Add a %Stakeholder{} struct specified by `stakeholder` to the CRM process at `pid`.

  returns {:ok, [%Stakeholders{}]}
  """
  def add_stakeholder_raw(pid, stakeholder) do
    GenServer.call(pid, {:add_stakeholder_raw, stakeholder})
  end

  def add_stakeholder(pid, stakeholder_name_opts) do
    GenServer.call(pid, {:add_stakeholder, stakeholder_name_opts})
  end

  @doc """
  Add an %Engagement{} specfied by `engagement` to the `stakeholder` in CRM process `pid`.

  returns {:ok, [%Stakeholders{}]}.
  """
  def add_engagement(pid, stakeholder, engagement) do
    GenServer.call(pid, {:add_engagement, {stakeholder, engagement}})
  end

  def update_stakeholder(pid, new_data) do
    GenServer.call(pid, {:update_stakeholder, new_data})
  end

  def add_stakeholder_date(pid, stakeholder, date, desc, reminder_int, annual) do
    with {:ok, new_data} <- Stakeholder.new_date(stakeholder, date, desc, reminder_int, annual) do
      GenServer.call(pid, {:update_stakeholder, new_data})
    else
      err -> err
    end
  end

  @doc """
  Asks the Crm processes at `pid` for its stored engagement types. 

  returns {:ok, [%EngagementType{}]}
  """
  def get_engagement_types(pid) do
    GenServer.call(pid, :get_engagement_types)
  end

  @doc """
  Adds an engagement with name `engagement_name`, due on `due_date` of the type specified by `type_name` the `stakeholder` at crm processes `pid`.
  `type_name` should be one of the type names returned by `get_engagement_types`.

  returns `{:ok, [%Stakeholders{}]}.
  """
  def add_new_engagement(pid, stakeholder, engagement_name, type_name, due_date) do
    {:ok, engagement} =
      GenServer.call(pid, {:new_engagement, {engagement_name, type_name, due_date}})

    add_engagement(pid, stakeholder, engagement)
  end

  @doc """
  Adds a new %EngagementType{} with the type name of `type` and `description` to the Crm processes at `pid`.

  returns `{:ok, [%EngagementType{}]}.
  """
  def put_engagement_type(pid, type, description) do
    t = %EngagementType{engagement_type: type, description: description}
    GenServer.call(pid, {:put_engagement_type, t})
  end

  def update_stakeholder_relationship(pid, stakeholder_uuid, relationship, value, focused) do
    with {:ok, stakeholder} <- get_stakeholder_by_uuid(pid, stakeholder_uuid) do
      {:ok, u_stk} =
        Stakeholder.update_relationship_metric(stakeholder, relationship, value, focused)

      GenServer.call(pid, {:update_stakeholder, u_stk})
    else
      err -> err
    end
  end

  def add_note_to_engagement(pid, stakeholder, engagement, note) do
    GenServer.call(pid, {:append_notes_to_engagement, stakeholder, engagement, note})
  end

  def set_engagement_state(pid, stakeholder, engagement, state) do
    GenServer.call(pid, {:set_engagement_state, stakeholder, engagement, state})
  end

  def complete_engagement_w_status(pid, stakeholder, engagement, result) do
    GenServer.call(pid, {:complete_engagement_w_status, stakeholder, engagement, result})
  end

  def update_stakeholder_attributes(pid, stakeholder_uuid, attribute, value) do
    with {:ok, stakeholder} <- get_stakeholder_by_uuid(pid, stakeholder_uuid) do
      {:ok, u_stk} = Stakeholder.update_attributes(stakeholder, attribute, value)
      GenServer.call(pid, {:update_stakeholder, u_stk})
    else
      err -> err
    end
  end

  def add_stakeholder_concern(pid, stakeholder_uuid, name, description, importance) do
    with {:ok, stakeholder} <- get_stakeholder_by_uuid(pid, stakeholder_uuid),
         {:ok, concern} = StakeholderConcern.new(name, description, importance) do
      {:ok, updated_stakeholder} = Stakeholder.update_concerns(stakeholder, concern)
      GenServer.call(pid, {:update_stakeholder, updated_stakeholder})
    else
      err -> err
    end
  end

  def mod_stakeholder_concern(pid, stakeholder, concern, nil) do
    with new_concerns <- Enum.reject(stakeholder.concerns, fn x -> x == concern end),
         updated_stakeholder <- Map.replace!(stakeholder, :concerns, new_concerns) do
      GenServer.call(pid, {:update_stakeholder, updated_stakeholder})
    else
      err -> err
    end
  end

  def mod_stakeholder_concern(pid, stakeholder, concern, new_data) do
    with concerns <- stakeholder.concerns,
         index <- Enum.find_index(concerns, fn x -> x == concern end),
         new_concerns <- List.replace_at(concern, index, new_data),
         updated_stakeholder <- Map.replace!(stakeholder, :concerns, new_concerns) do
      GenServer.call(pid, {:update_stakeholder, updated_stakeholder})
    else
      err -> err
    end
  end

  @doc """
  Gets `[%Stakeholder{}]`s who have not been contacted in `past_threshold` days or will be contacted within `future_threshold` days.

  returns `{:ok, [%Stakeholder{}]}`.
  """
  def get_neglected_stakeholders(pid, past_threshold, future_threshold) do
    GenServer.call(pid, {:get_neglected_stakeholders, past_threshold, future_threshold})
  end

  @doc """
  Gets `[%Stakeholder{}]`s who have not been contacted in `past_threshold` days or will be contacted within `future_threshold` days.

  returns `{:ok, [%Stakeholder{}]}`.
  """
  def get_upcoming_dates(pid) do
    GenServer.call(pid, :get_upcoming_dates)
  end

  @doc """
  Defers the `engagement` of `stakeholder` by `delay`. 
  Creates a new engement with the same information as the original but with the date pushed out.
  Marks the original engagement's state to deferred. 

  returns `{:ok, [%Stakeholders{}]}.
  """
  def defer_engagement(pid, stakeholder, engagement, delay) do
    GenServer.call(pid, {:defer_engagement, stakeholder, engagement, delay})
  end

  def delete_stakeholder(pid, stakeholder) do
    GenServer.call(pid, {:del_stakeholder, stakeholder})
  end

  def get_stakeholder_by_uuid(pid, uuid) do
    GenServer.call(pid, {:get_stakeholder, uuid, :uuid})
  end

  @doc """
  adds an engagement to the stakeholder
  """
  def handle_call({:new_engagement, {engagement_name, type_name, due_date}}, _from, state) do
    with type <- Enum.find(state.engagement_types, fn x -> x.engagement_type == type_name end),
         {:ok, date} <- Date.from_iso8601(due_date) do
      engagement = Engagement.new(self(), engagement_name, type, date)
      {:reply, engagement, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call(:get_engagement_types, _from, state) do
    {:reply, state.engagement_types, state}
  end

  def handle_call({:defer_engagement, stakeholder, engagement, delay}, _from, state) do
    with {:ok, new_timeline} <-
           MitraCrm.Engagement.defer_and_update_engagements(
             stakeholder.timeline,
             engagement,
             delay
           ),
         new_data <- Map.put(stakeholder, :timeline, new_timeline),
         {:ok, stakeholders} <- Stakeholder.replace_stakeholder(state.stakeholders, new_data) do
      new_state = update_stakeholder_state(state, stakeholders)
      {:reply, new_state.stakeholders, new_state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:put_engagement_type, type}, _from, state) do
    new_enagement_types = [type | state.engagement_types]
    new_state = Map.put(state, :engagement_types, new_enagement_types)
    {:reply, new_enagement_types, new_state}
  end

  def handle_call(:get_upcoming_dates, _from, state) do
    dates = Stakeholder.get_all_stakeholder_dates(state.stakeholders)
    {:reply, dates, state}
  end

  def handle_call({:get_neglected_stakeholders, past_threshold, future_threshold}, _from, state) do
    stakeholders = state.stakeholders

    neglected =
      Stakeholder.get_neglected_stakeholders(stakeholders, past_threshold, future_threshold)

    count = length(neglected)
    {:reply, {count, neglected}, state}
  end

  def handle_call({:load_from_file, filename}, _from, state) do
    with {:ok, stakeholders} <- Stakeholderpersistence.load_stakeholders_from_file(filename) do
      state = update_stakeholder_state(state, stakeholders)
      {:reply, state, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call(:get_stakeholders, _from, state) do
    {:reply, state.stakeholders, state}
  end

  def handle_call({:del_stakeholder, stakeholder}, _from, state) do
    with stakeholders <- state.stakeholders,
         new_stakeholders <- Enum.reject(stakeholders, fn x -> x == stakeholder end),
         state = update_stakeholder_state(state, new_stakeholders) do
      {:reply, state.stakeholders, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:add_stakeholder, stakeholder_name_opts}, _from, state) do
    with {:ok, stakeholder} <- Stakeholder.new(stakeholder_name_opts),
         stakeholders <- state.stakeholders do
      state = update_stakeholder_state(state, [stakeholder | stakeholders])
      {:reply, state.stakeholders, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:add_stakeholder_raw, stakeholder}, _from, state) do
    with stakeholders <- state.stakeholders do
      state = update_stakeholder_state(state, [stakeholder | stakeholders])
      {:reply, state.stakeholders, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:get_stakeholder, uuid, :uuid}, _from, state) do
    with {:ok, stakeholder} <- Stakeholder.get_stakeholder_by_uuid(state.stakeholders, uuid) do
      {:reply, {:ok, stakeholder}, state}
    else
      err -> {:reply, err, state}
    end
  end

  def handle_call({:update_stakeholder, new_data}, _from, state) do
    with {:ok, stakeholders} <- Stakeholder.replace_stakeholder(state.stakeholders, new_data) do
      new_state = update_stakeholder_state(state, stakeholders)
      {:reply, new_state.stakeholders, new_state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:set_engagement_state, stakeholder, engagement, st}, _from, state) do
    with new_engagement <- Map.replace!(engagement, :state, st),
         updated_engagements <-
           MitraCrm.Engagement.update_engagements(
             stakeholder.timeline,
             engagement,
             new_engagement
           ),
         updated_stakeholder <- Map.replace!(stakeholder, :timeline, updated_engagements),
         {:ok, stakeholders} <-
           Stakeholder.replace_stakeholder(state.stakeholders, updated_stakeholder) do
      new_state = update_stakeholder_state(state, stakeholders)
      {:reply, new_state.stakeholders, new_state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:append_notes_to_engagement, stakeholder, engagement, note}, _from, state) do
    with new_engagement <- Map.replace!(engagement, :notes, engagement.notes <> "\n" <> note),
         updated_engagements <-
           MitraCrm.Engagement.update_engagements(
             stakeholder.timeline,
             engagement,
             new_engagement
           ),
         updated_stakeholder <- Map.replace!(stakeholder, :timeline, updated_engagements),
         {:ok, stakeholders} <-
           Stakeholder.replace_stakeholder(state.stakeholders, updated_stakeholder) do
      new_state = update_stakeholder_state(state, stakeholders)
      {:reply, new_state.stakeholders, new_state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:complete_engagement_w_status, stakeholder, engagement, result}, _from, state) do
    with new_engagement <-
           Map.replace!(engagement, :result, result)
           |> Map.replace!(:state, :complete),
         updated_engagements <-
           MitraCrm.Engagement.update_engagements(
             stakeholder.timeline,
             engagement,
             new_engagement
           ),
         updated_stakeholder <- Map.replace!(stakeholder, :timeline, updated_engagements),
         {:ok, stakeholders} <-
           Stakeholder.replace_stakeholder(state.stakeholders, updated_stakeholder) do
      new_state = update_stakeholder_state(state, stakeholders)
      {:reply, new_state.stakeholders, new_state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:add_engagement, {stakeholder, engagement}}, _from, state) do
    with {:ok, new_stakeholder} <-
           Stakeholder.add_engagement_to_timeline(stakeholder, engagement),
         index <- Enum.find_index(state.stakeholders, fn x -> x == stakeholder end),
         new_stakeholders <- List.replace_at(state.stakeholders, index, new_stakeholder) do
      new_state = update_stakeholder_state(state, new_stakeholders)
      {:reply, {:ok, new_stakeholders}, new_state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:load_state_file, filename}, _from, state) do
    with {:ok, new_state} <-
           MitraCrm.CrmStatepersistence.load(state.persistence_pid, filename, state.user.id) do
      updated_state =
        state
        |> Map.put(:stakeholders, new_state.stakeholders)
        |> Map.put(:engagement_types, new_state.engagement_types)

      {:reply, {:ok}, updated_state}
    else
      {:error, :not_found} -> {:reply, {:error, :state_not_found}, state}
      err -> err
    end
  end

  def handle_call(:load_state_proc, _from, state) do
    with {:ok, new_state} <- MitraCrm.CrmStatepersistence.load(state.persistence_pid) do
      updated_state =
        state
        |> Map.put(:stakeholders, new_state.stakeholders)
        |> Map.put(:engagement_types, new_state.engagement_types)

      {:reply, {:ok}, updated_state}
    else
      {:error, :not_found} -> {:reply, {:error, :state_not_found}, state}
      err -> {:reply, err, state}
    end
  end

  def handle_call({:persist_state, filename}, _from, state) do
    with {:ok} <- MitraCrm.CrmStatepersistence.write(state.persistence_pid, filename, state) do
      {:reply, :ok, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call(:persist_state_proc, _from, state) do
    with {:ok} <- MitraCrm.CrmStatepersistence.write(state.persistence_pid, state) do
      {:reply, :ok, state}
    else
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_cast({:load_from_file, filename}, state) do
    with {:ok, stakeholders} <- Stakeholderpersistence.load_stakeholders_from_file(filename) do
      state = update_stakeholder_state(state, stakeholders)
      {:noreply, state}
    end
  end

  def handle_cast({:persist_state, filename}, state) do
    with {:ok} <- MitraCrm.CrmStatepersistence.write(state.persistence_pid, filename, state) do
      {:noreply, state}
    end
  end

  def handle_info({:EXIT, dead_pid, _reason}, state) do
    # Start new process based on dead_pid spec
    {:ok, persistence_pid} = MitraCrm.CrmStatepersistence.start_link()

    # Remove the dead_pid and insert the new_pid with its spec
    new_state =
      state
      |> Map.delete(:persistence_pid)
      |> Map.put(:persistence_pid, persistence_pid)

    {:noreply, new_state}
  end

  defp write_impl()

  defp update_stakeholder_state(state, stakeholders) do
    Map.put(state, :stakeholders, stakeholders)
  end

  def from_json!(json) do
    {:ok, state} = from_json(json)
    state
  end

  def to_json!(state) do
    {:ok, json} = to_json(state)
    json
  end

  def to_json(state) do
    Map.delete(state, :persistence_pid)
    |> Poison.encode()
  end

  def from_json(json) do
    with {:ok, state} =
           Poison.decode(json,
             as: %Crm{
               user: %{id: 0},
               stakeholders: [
                 %Stakeholder{
                   meta: %StakeholderMetadata{},
                   name: %StakeholderName{},
                   relationship: %StakeholderRelationship{
                     credability: %StakeholderRelationshipValue{metric: 0, focused: false},
                     reliability: %StakeholderRelationshipValue{metric: 0, focused: false},
                     empathy: %StakeholderRelationshipValue{metric: 0, focused: false},
                     stakeholderfocus: %StakeholderRelationshipValue{metric: 0, focused: false}
                   },
                   timeline: [%Engagement{}],
                   dates: [
                     %StakeholderDate{date: nil, description: nil, reminder: nil, annual: nil}
                   ],
                   attributes: %{},
                   concerns: [
                     %StakeholderConcern{
                       name: "untitled",
                       description: "untitled",
                       importance: 0,
                       resolved: false,
                       date_added: Date.utc_today()
                     }
                   ],
                   contact_information: %{}
                 }
               ],
               engagement_types: [%EngagementType{}]
             }
           ) do
      {:ok,
       %{
         user: %{id: Map.get(state.user, "id")},
         stakeholders: state.stakeholders,
         engagement_types: state.engagement_types
       }}
    end
  end
end
