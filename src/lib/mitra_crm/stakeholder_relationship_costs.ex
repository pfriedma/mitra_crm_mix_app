defmodule MitraCrm.StakeholderRelationshipCosts do
    alias MitraCrm.{StakeholderRelationshipCosts,StakeholderRelationship}

    @default_costs %{
        defer: %{
            reliability: -1,
            credability: -1,
            empathy: 0,
            stakeholderfocus: 0 }
    }
    
    def cost(action) do
        with {:ok, cost_map} <- get_cost_map([]) do
            cost_map[action]
        else
             err -> err
        end
    end

    def apply_cost(relationship, action) do
        with {:ok, cost_map} <- cost(action)
        do
            {:ok}
        else
            err -> err
        end
    end

    defp get_cost_map(_user) do
        {:ok, @default_costs}
    end

end