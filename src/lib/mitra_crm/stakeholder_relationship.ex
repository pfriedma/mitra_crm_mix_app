defmodule MitraCrm.StakeholderRelationship do
    alias MitraCrm.{StakeholderRelationship,StakeholderRelationshipValue}
    @derive [Poison.Encoder]
    @enforce_keys [:reliability, :credability, :empathy, :stakeholderfocus]
    defstruct [:reliability, :credability, :empathy, :stakeholderfocus]
    
    def new() do
        with {ok, new_relationship} <- StakeholderRelationshipValue.new do
        {:ok, %StakeholderRelationship{
            reliability: new_relationship,
            credability: new_relationship, 
            empathy: new_relationship,
            stakeholderfocus: new_relationship
        }}
        end
    end 

    def update_relationship(relationship, dimension, value, focus) do
        {:ok, rel} = StakeholderRelationshipValue.new(value, focus)
        relationships = Map.put(relationship, dimension, rel)
        {:ok, relationship}
    end


end