defmodule MitraCrm.StakeholderConcern do
    alias __MODULE__
    @derive [Poison.Encoder]
    @enforce_keys [:name, :description, :importance, :resolved, :date_added]
    defstruct [:name, :description, :importance, :resolved, :date_added]
    

    def new(name, description, importance) do
        concern = %StakeholderConcern{ name: name, description: description, importance: importance, resolved: false, date_added: Date.utc_today() }
        {:ok, concern}
    end

end