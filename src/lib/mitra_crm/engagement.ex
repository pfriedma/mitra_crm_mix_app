defmodule MitraCrm.Engagement do
    alias MitraCrm.{Stakeholder,Engagement,EngagementType,StakeholderRelationship, StakeholderRelationshipCosts}
    @derive [Poison.Encoder]
    defstruct [:uuid, :due_date, :name, :notes, :engagement_type, :action_items, :state, :result]

    @eng_states [:open, :in_progress, :complete, :deferred, :canceled] 
    @eng_results [:success, :failure]
    @default_threshhold 7


    defimpl Poison.Decoder, for: Engagement do
        def decode(%{
            uuid: uuid, 
            due_date: due_date, 
            name: name,
            notes: notes,
            action_items: action_items,
            state: state,
            result: result,
            engagement_type: %{"description" => ed, "engagement_type" => et}
        }, options) do
            uid = if is_nil(uuid), do: UUID.uuid1(:urn), else: uuid
            %Engagement{ 
                uuid: uid,
                due_date: Date.from_iso8601!(due_date),
                name: name, 
                notes: notes,
                action_items: action_items,
                state: String.to_existing_atom(state),
                result: result,
                engagement_type: %EngagementType{description: ed, engagement_type: et}
            }
        end
    end


    def new(name,engagement_type,due_date) do
        case valid_engagement_type?(engagement_type) do
            true -> {:ok, %Engagement{due_date: due_date, name: name, notes: " ", engagement_type: engagement_type, action_items: [], state: :open, result: nil}}
            false -> {:error, :invalid_engagement_type}
            _ -> {:error, :engagement_type_retreival_error}
        end
    end

    def new(pid,name,engagement_type,due_date) do
        case valid_engagement_type?(engagement_type,pid) do
            true -> {:ok, %Engagement{uuid: UUID.uuid1(:urn), due_date: due_date, name: name, notes: " ", engagement_type: engagement_type, action_items: [], state: :open, result: nil}}
            false -> {:error, :invalid_engagement_type}
            _ -> {:error, :engagement_type_retreival_error}
        end
    end

    defp valid_state?(state) do
        state in @eng_states
    end


    defp valid_result?(result) do
        result in @eng_results
    end

    defp valid_engagement_type?(engagement_type, pid) do
        with {:ok, types} <- EngagementType.get_engagement_types(pid)
            do
                engagement_type in types
            else 
              _ -> :error
        end
    end
    defp valid_engagement_type?(engagement_type) do
        with {:ok, types} <- EngagementType.get_engagement_types(nil)
            do
                engagement_type in types
            else 
              _ -> :error
        end
    end

    def defer_engagement(engagement, deferrment) do
        # FIXME add cost functions
        with new_engagement_date <- Date.add(engagement.due_date, deferrment)
            do
                new_engagement = %Engagement{engagement | due_date: new_engagement_date, state: :open}
                old_engagement = %Engagement{engagement | state: :deferred}
                {:ok, [new_engagement,old_engagement]}
            else
                err -> err
        end
    end

    def defer_and_update_engagements(engagements, engagement, deferrment) do
        with {:ok, deferred_engagement} <- defer_engagement(engagement, deferrment),
            filtered_engagements <- Enum.reject(engagements, fn x -> x == engagement end)
        do
            engagements = filtered_engagements ++ deferred_engagement
            {:ok, sort_engagements(engagements)}
        else    
            err -> err
        end
    end

    def get_upcoming_engagements([], threshold) do 
        {:ok, []}
    end
    def get_upcoming_engagements(engagements, threshold) do 
        {:ok, Enum.filter(engagements, fn x -> upcoming_engagement?(x,threshold) end )}
    end

    def get_upcoming_engagements!(engagements, threshold) do
        {:ok, upcoming_engagements} = get_upcoming_engagements(engagements, threshold)
        upcoming_engagements
    end

    def get_upcoming_engagements!(engagements) do
        {:ok, upcoming_engagements} = get_upcoming_engagements(engagements)
        upcoming_engagements
    end

    def get_upcoming_engagements(engagements) do
        get_upcoming_engagements(engagements, @default_threshhold)
    end

    def update_engagements(engagements, engagement, update) do 
        List.replace_at(engagements, Enum.find_index(engagements, fn x -> x == engagement end), update)
        |> sort_engagements
    end

    defp upcoming_engagement?(engagement, threshold) do
        with reminder_date <- Date.add(Date.utc_today, threshold),
        state <- engagement.state 
        do 
            difference = Date.diff(reminder_date, engagement.due_date)
            difference <= threshold and difference > 0 and not (state == :canceled or state == :complete or state == :deferred)
        end
    end
    
    def sort_engagements(engagements) do
        Enum.sort_by(engagements, fn y -> {y.due_date.year, y.due_date.month, y.due_date.day} end)
    end

    def last_engagement(engagements) do 
        today = Date.utc_today
        sorted_engagements = sort_engagements(engagements)
        {:ok, Enum.filter(
            engagements, 
            fn d -> 
                Date.compare(
                    d.due_date, Date.utc_today
                ) == :lt 
            end)
        |> Enum.reverse 
        |> List.first}
    end

end