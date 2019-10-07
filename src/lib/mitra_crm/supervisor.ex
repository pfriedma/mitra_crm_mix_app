defmodule MitraCrm.Supervisor do
    # Automatically defines child_spec/1
    use Supervisor
  


    def start_link([name, id]) do
      Supervisor.start_link(__MODULE__, id, name: name)
    end
  
    @impl true
    def init(id) do
        p_type = Application.get_env(:mitra_crm, :persistence_type)
        p_uri = Application.get_env(:mitra_crm, :persistence_uri)
      children = [
        {MitraCrm.Crm, [id, p_uri, p_type]}
      ]
  
      Supervisor.init(children, strategy: :one_for_one)

    end
  end