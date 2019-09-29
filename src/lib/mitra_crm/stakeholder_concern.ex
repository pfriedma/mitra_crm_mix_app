defmodule MitraCrm.StakeholderConcern do
    alias __MODULE__
    @derive [Poison.Encoder, Poison.Decoder]
    @enforce_keys [:name, :description, :importance, :resolved, :date_added]
    defstruct [:name, :description, :importance, :resolved, :date_added]
    
    defimpl Poison.Decoder, for: StakeholderConcern do
        def decode(%{
            date_added: date_added, 
            description: description,
            importance: importance,
            name: name,
            resolved: resolved
            }, options) do
            %StakeholderConcern{ 
                date_added: Date.from_iso8601!(date_added),
                description: description,
                importance: importance,
                name: name,
                resolved: resolved
            }
        end
    end

    def new(name, description, importance) do
        concern = %StakeholderConcern{ name: name, description: description, importance: importance, resolved: false, date_added: Date.utc_today() }
        {:ok, concern}
    end

end