defmodule MitraCrm.Stakeholder do
    @moduledoc """
    This is the Stakeholder module.
    Handles data of individual stakeholder.

    """

    alias MitraCrm.{StakeholderMetadata, StakeholderName, Stakeholder, StakeholderConcern, StakeholderDate, StakeholderRelationship, StakeholderRelationshipValue, Engagement}
    @derive [Poison.Encoder]
    #@enforce_keys [:name]
    defstruct [:meta, :name, :dates, :attributes, :concerns, :relationship, :contact_information, :timeline ]

    defimpl Poison.Decoder, for: Staekholder do
        def decode(json, options) do
            MitraCrm.Stakeholder.to_json(json)
        end
    end


    @doc """
    Creates a new stakeholder with the `given_name` and `family_name`.

    Returns `{:ok, stakeholder}`.

    """

    def new(name_opts) when is_list(name_opts) do 
        {:ok, relationship} = StakeholderRelationship.new()
        {:ok, meta} = StakeholderMetadata.new()
        {:ok, name} = StakeholderName.new(name_opts)
        {:ok, %Stakeholder{meta: meta, name: name, dates: [], attributes: %{}, concerns: [], relationship: relationship, contact_information: %{}, timeline: []}}
    end

    def new(given_name, family_name) do
        name_opts = [given_name: given_name, family_name: family_name]
        new(name_opts)
    end

    def new(name) do
        new(name, nil)
    end

    @doc """
    Updates `stakeholder` with a `date`.

    Returns `{:ok, stakeholder}`.

    """
    def update_dates(stakeholder, date) do
        dates = [date | stakeholder.dates] |> Enum.uniq
        updated_stakeholder = %Stakeholder{ stakeholder | dates: dates }
        |> update_meta_date
        {:ok, updated_stakeholder}
    end

    def update_name(stakeholder, name) do
        updated_stakeholder = %Stakeholder{ stakeholder | name: name }
        |> update_meta_date
        {:ok, updated_stakeholder}
    end

    @doc """
    Updates `stakeholder` with a new StakeholderDate specified by:

    ## Parameters

    - `date`: date of the event in ISO-8601 format string.
    - `description`: description of the date (e.g. "Pet's Birthday").
    - `reminder`: how far in advance (in integer days) a reminder should occur.
    - `annual`: a true/false parameter of whether the event is annual.

    Returns `{:ok, stakeholder}`.

    """
    def new_date(stakeholder, date, description, reminder, annual) do
        {:ok, date} = StakeholderDate.new_from_str(date, description, reminder, annual)
        update_dates(stakeholder, date)
    end

    @doc """
    Updates `stakeholder` with a new `attribute` whoose value is `value`.

    Returns `{:ok, stakeholder}`.

    """
    def update_attributes(stakeholder, attribute, value) do
        attributes = Map.put(stakeholder.attributes, attribute, value)
        updated_stakeholder = %Stakeholder{ stakeholder | attributes: attributes }
        |> update_meta_date
        {:ok, updated_stakeholder}
    end

    @doc """
    Updates `stakeholder` contact information, setting `contact_title` to `value`.

    Returns `{:ok, stakeholder}`.

    """
    def update_contact(stakeholder, contact_title, value) do 
        contacts = Map.put(stakeholder.contact_information, contact_title, value)
        updated_stakeholder = %Stakeholder{ stakeholder | contact_information: contacts}
        |> update_meta_date
        {:ok, updated_stakeholder}
    end

    @doc """
    Updates `stakeholder` with a new `concern`.

    Returns `{:ok, stakeholder}`.

    """
    def update_concerns(stakeholder, concern) do
        concerns = [concern | stakeholder.concerns] |> Enum.uniq
        updated_stakeholder = %Stakeholder{ stakeholder | concerns: concerns }
        |> update_meta_date
        {:ok, updated_stakeholder}
    end

    @doc """
    Updates `stakeholder` with a new concern specified by the concerns `name`, a `description` of the concern, and the `importance` of the concern (Range[0..9]).

    Returns `{:ok, stakeholder}`.
    """
    def new_concern(stakeholder, name, description, importance) do
        {:ok, concern} = StakeholderConcern.new(name, description, importance)
        update_concerns(stakeholder, concern)
    end

    @doc """
    Updates `stakeholder` with a new `relationship`.

    Returns `{:ok, stakeholder}`.

    """
    def update_relationship(stakeholder, relationship) do
        updated_stakeholder = %Stakeholder{stakeholder | relationship: relationship}
        |> update_meta_date
        {:ok, updated_stakeholder}
    end


    @doc """
    Updates `stakeholder` relationship `dimension` to the `value` and `focus` specified.

    ## Parameters
    - `dimension` is one of [`:credability`, `:empathy`, `:reliability`, `:stakeholderfocus`].
    - `value` is in Range[0..9].
    - `focus` is whether or not you are focusing on building that relationship dimension.

    ## Notes
    `:stakeholderfocus` is a metric around how much you focus on the `stakeholder`'s needs as opposed to your own.
  
    Returns `{:ok, stakeholder}`.

    """
    def update_relationship_metric(stakeholder, dimension, value, focus) do
        relationship = stakeholder.relationship
        rel = StakeholderRelationship.update_relationship(relationship, dimension, value, focus)
        update_relationship(stakeholder, rel)
    end

    @doc """
    Updates `stakeholder` with a new `engagement`.

    Returns `{:ok, stakeholder}`.

    """
    def add_engagement_to_timeline(stakeholder, engagement) do
        engagements = add_engagements(engagement, stakeholder.timeline) |> Enum.uniq |> Engagement.sort_engagements
        updated_stakeholder = %Stakeholder{stakeholder | timeline: engagements} 
        |> update_meta_date
        {:ok, updated_stakeholder}
    end

    @doc """
    Updates multiple `stakeholders` adding `engagement` to each.

    Returns `[stakeholder]`.

    """
    def add_engagement_to_stakeholders_timeline(stakeholders, engagement) when is_list(stakeholders) do
        Enum.map(stakeholders, 
        fn stakeholder -> 
            (fn {:ok, x} -> x end)
            .(Stakeholder.add_engagement_to_timeline(
                stakeholder, engagement
                )
            ) 
        end )
    end

    @doc """
    Gets the important upcoming dates for `stakeholders`.

    Returns `%{engagements: [%Engagement{}], important_dates: [%StakeholderDate{}]}`.

    """
    def get_all_stakeholder_dates(stakeholders) when is_list(stakeholders) do
        engagements = Enum.map(stakeholders, fn x -> enagements = %{uid: x.meta.uuid, name: x.name, engagments: Engagement.get_upcoming_engagements!(x.timeline)} end )
            |> Enum.filter(fn {x,l} -> length(l) > 0 end)
        dates = Enum.map(stakeholders, fn x -> %{uid: x.meta.uuid, name: x.name, dates: get_upcoming_dates!(x)} end )
            |> Enum.filter(fn {x,l} -> length(l) > 0 end)
        %{engagements: engagements, important_dates: dates}
    end

    @doc """
    Gets upcomming dates for `stakeholder`.

    Returns `[%StakeholderDate]`.

    """
    def get_upcoming_dates!(stakeholder) do
        {:ok, dates} = get_upcoming_dates(stakeholder)
        dates
    end

    @doc """
    Gets upcomming dates for `stakeholder`.

    Returns `{:ok, [%StakeholderDate]}`.

    """
    def get_upcoming_dates(stakeholder) do
        dates = stakeholder.dates
        {:ok, Enum.filter(dates, fn x -> StakeholderDate.is_upcoming(x) end )}
    end

    @doc """
    Determines if any stakeholders in `stakeholders` haven't been contacted in a while.

    Returns `[%Stakeholder{}]` if the stakeholder hasn't been engaged since `past_threshold` or will be engaged before `future_threshold` (in days).

    """
    def get_neglected_stakeholders(stakeholders, past_threshold, future_threashold) do
        Enum.filter(
            stakeholders,
            fn stakeholder -> 
                neglected_stakeholder?(stakeholder, past_threshold, future_threashold)
            end
        )
    end

    @doc """
    Returns the first `%Stakeholder{}` with `name` from an array of stakeholders.

    Returns `{:ok, stakeholder}` or `{:error, :not_found}`
    """
    def get_stakeholder_by_name(stakeholders, stakeholder_name) do
        case Enum.find(stakeholders, nil, fn x -> x.name == stakeholder_name end) do
            nil -> {:error, :not_found}
            s when is_map(s) -> {:ok, s}
            err -> {:error, err}
        end
    end

    def get_stakeholder_by_uuid(stakeholders, stakeholder_uuid) do 
        case Enum.find(stakeholders, nil, fn x -> x.meta.uuid == stakeholder_uuid end) do
            nil -> {:error, :not_found}
            s when is_map(s) -> {:ok, s} 
            err -> {:error, err}
        end
    end

    def exists?(stakeholders, uuid, :uuid) do 
        with {:ok, stakeholder} <- get_stakeholder_by_uuid(stakeholders, uuid) do
            true
        else
            {:error, :not_found} -> false
            err -> err
        end
    end

    def exists?(stakeholders, name, :name) do
        with {:ok, stakeholder} <- get_stakeholder_by_name(stakeholders, name) do 
            true
        else
            {:error, :not_found} -> false
            err -> err
        end
    end

    def exists?(stakeholders, stakeholder) do
        Enum.any?(stakeholders, fn x -> x == stakeholder end)
    end

    def replace_stakeholder(stakeholders, stakeholder) do
        add_stakeholder(stakeholders, stakeholder, true)
    end


    @doc """
    Adds the `stakeholder` to the list of `stakeholders`
    Replaces an existing stakeholder if `replace` is true.

    Returns `{:ok, stakeholders}` if the stakeholder was added and didn't already exist.
    Returns `{:error, {:duplicate, stakeholder}}` if the stakeholder already exists and `replace` is false.
    """
    defp add_stakeholder(stakeholders, stakeholder, replace) do
        uuid = stakeholder.meta.uuid
        if exists?(stakeholders, uuid, :uuid) && replace == false do
            {:error, {:duplicate, stakeholder}}
        else 
            filtered_stakeholders = Enum.reject(stakeholders, fn x -> x.meta.uuid == uuid end)
            stakeholder = update_meta_date(stakeholder)
            updated_stakeholders = [stakeholder | filtered_stakeholders ]
            {:ok, updated_stakeholders}
       end    
    end

    @doc """
    Determines if any `stakeholder` hasn't been contacted in a while.

    Returns `true` if the stakeholder hasn't been engaged since `past_threshold` or will be engaged before `future_threshold` (in days).

    """
    def neglected_stakeholder?(stakeholder,past_threshold, future_threashold) do 
        with {:ok, last_past_engagement} <- Engagement.last_engagement(stakeholder.timeline),
             {:ok, upcoming_engagements} <- Engagement.get_upcoming_engagements(stakeholder.timeline, future_threashold),
             today <- Date.utc_today,
             ucl = length(upcoming_engagements)
        do
            if last_past_engagement != nil do
                Date.diff(today, last_past_engagement.due_date) >= past_threshold and ucl == 0
            else
                ucl == 0
            end
        else
            err -> err
        end
    end


    defp add_engagements(engagements, timeline) when is_list(engagements) do
        engagements ++ timeline
    end

    defp add_engagements(engagement, timeline) when is_map(engagement) do 
        [engagement | timeline]
    end

    defp update_metadata(meta, stakeholder) do
        %Stakeholder{stakeholder | meta: meta}
    end

    defp update_meta_date(stakeholder) do
        stakeholder.meta
        |> StakeholderMetadata.update_meta_date
        |> update_metadata(stakeholder)
    end


    @doc """
    Exports `stakeholder` to json.

    Returns `json`.

    """
    def to_json!(stakeholder) do
        {:ok, json} = to_json(stakeholder)
        json
    end

    @doc """
    Exports `stakeholder` to json.

    Returns `{:ok, json}`.
    
    """
    def to_json(stakeholder) do
        Poison.encode(stakeholder)
    end

    @doc """
    Imports a stakeholder from `json`.

    Returns `stakeholder`.
    
    """
    def from_json!(json) do
        {:ok, stakeholder} = from_json(json)
        stakeholder
    end

    @doc """
    Imports a stakeholder from `json`.

    Returns `{:ok, stakeholder`}.
    
    """
    def from_json(json) do 
        Poison.decode(json, as: %Stakeholder{
            meta: %StakeholderMetadata{},
            name: %StakeholderName{},
            relationship: %StakeholderRelationship{
                credability: %StakeholderRelationshipValue{metric: 0, focused: false},
                reliability: %StakeholderRelationshipValue{metric: 0, focused: false},
                empathy: %StakeholderRelationshipValue{metric: 0, focused: false},
                stakeholderfocus: %StakeholderRelationshipValue{metric: 0, focused: false},
            },
            timeline: [%Engagement{}],
            dates: [%StakeholderDate{date: nil, description: nil, reminder: nil, annual: nil}],
            attributes: %{},
            concerns: [%StakeholderConcern{name: "untitled", description: "untitled", importance: 0, resolved: false, date_added: Date.utc_today}],
            contact_information: %{},
            
        })


    end

    # TODO - Add validation on name not being 0 length or duplicate
end