defmodule MitraCrm.EngagementType do
    alias MitraCrm.EngagementType
    @derive [Poison.Encoder, Poison.Decoder]
    
    defstruct [:engagement_type, :description] 
    

    def get_engagement_types(engagement_types) do
        {:ok, defaults} = get_default_engaement_types()
        user_engagement_types = engagement_types
        {:ok, defaults ++ user_engagement_types}
    end

    def get_default_engaement_types() do
        defaults = [
            %EngagementType{ engagement_type: "In Person", description: "An in-person engagement"},
            %EngagementType{ engagement_type: "Phone Call", description: "A telephine call"},
            %EngagementType{ engagement_type: "Email", description: "An email"},
            %EngagementType{ engagement_type: "Action Item / Deliverable", description: "A work pacakge"}
        ]
        {:ok, defaults}
    end

    def lookup_type!(engagement_type) do 
        {:ok, type} = lookup_type(engagement_type)
        type
    end


    def lookup_type(engagement_type) do
        with {:ok, types} <- get_engagement_types([])
        do  
            type = Enum.find(types, fn x -> x.engagement_type == engagement_type end)
            {:ok, type}
        end
    end




    
end