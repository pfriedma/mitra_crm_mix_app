defmodule MitraCrm.StakeholderRelationshipValue do
    alias __MODULE__
    @derive [Poison.Encoder]
    @enforce_keys [:metric, :focused]
    defstruct [metric: 0, focused: false]
    
    
    def new() do
        {:ok, %StakeholderRelationshipValue{metric: 0, focused: false}}
    end

    def new(metric,focused) do
        {:ok, %StakeholderRelationshipValue{metric: metric, focused: focused}}
    end
end