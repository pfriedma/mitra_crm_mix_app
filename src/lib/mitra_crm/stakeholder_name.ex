defmodule MitraCrm.StakeholderName do
    @moduledoc """
    This is the Stakeholder module.
    Handles data of individual stakeholder.

    """

    alias MitraCrm.{StakeholderName}
    @derive [Poison.Encoder, Poison.Decoder]
    #@enforce_keys [:name]
    defstruct [:given_name, :family_name, :middle_name, :middle_initial, :prefix, :suffix]

    def new(given_name, family_name) do
        opts = [given_name: given_name, family_name: family_name]
        new(opts)
    end

    def new(opts) do
        with name <- struct(StakeholderName, opts) do
            {:ok, name}
        else
            err -> err
        end
    end


end