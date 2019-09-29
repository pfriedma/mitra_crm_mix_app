defmodule MitraCrm.StakeholderMetadata do
    @moduledoc """
    This is the Stakeholder Metadata module.

    """

    alias MitraCrm.{StakeholderMetadata}
    @derive [Poison.Encoder]
    #@enforce_keys [:name]
    defstruct [:uuid, :updated_date, crm_uids: [], shared: false, persistence_type: :json, persistence_uri: ""] 

    defimpl Poison.Decoder, for: StakeholderMetadata do
        def decode(%{
            uuid: uuid, 
            updated_date: date,
            crm_uids: crm_uids,
            shared: shared,
            persistence_type: persistence_type,
            persistence_uri: persistence_uri,
        }, options) do
            with {:ok, datetime, _} <- DateTime.from_iso8601(date) do
                %StakeholderMetadata{ 
                    uuid: uuid,
                    updated_date: datetime,
                    crm_uids: crm_uids,
                    shared: shared,
                    persistence_type: String.to_existing_atom(persistence_type),
                    persistence_uri: persistence_uri
                }
            else 
                err -> err
            end
        end
    end

    def new() do
        StakeholderMetadata.new(nil)
    end

    def new(crm_uid) do
        {:ok, %StakeholderMetadata{uuid: UUID.uuid1(:urn), updated_date: DateTime.utc_now(), crm_uids: [crm_uid], shared: false, persistence_type: :json, persistence_uri: ""}}
    end

    def add_crm_uid(meta, uid) do 
        [uid | Enum.reject(meta.crm_uids, fn x -> x == uid end)]
        |> update_crm_uids(meta)
        |> update_meta_date
    end

    def del_crm_uid(meta, uid) do 
        Enum.reject(meta.crm_uids, fn x -> x == uid end)
        |> update_crm_uids(meta)
        |> update_meta_date
    end
    
    def update_meta_date(meta) do 
        %StakeholderMetadata{meta | updated_date: DateTime.utc_now()}
    end

    defp update_crm_uids(uids, meta) do
        %StakeholderMetadata{meta | crm_uids: uids}
    end

end