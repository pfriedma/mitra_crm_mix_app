defmodule MitraCrm.StakeholderPersistance do

    alias MitraCrm.{StakeholderPersistance,Stakeholder}

    def load_stakeholders_from_file!(filename) do
        {:ok, stakeholders} = load_stakeholders_from_file(filename)
        stakeholders
    end

    def load_stakeholders_from_file(filename) do
        with stream <- File.stream!(filename, [:read], :line),
            ops <- Stream.map(stream, fn x -> Stakeholder.from_json!(x) end ),
            stakeholders <- Enum.to_list(ops)
        do
            {:ok, stakeholders}
        else
            err -> err
        end
    end


    def append_stakeholders_to_file(filename, stakeholders) do 
        write_stakeholders_to_file(filename, stakeholders, [:append])
    end

    def ovewrite_stakeholders_to_file(filename, stakeholders) do
        write_stakeholders_to_file(filename, stakeholders, [:write])
    end

    def write_stakeholders_to_file(filename, stakeholders, mode) do
        with stream <- File.stream!(filename, mode, :line)
        do
            Stream.into(stakeholders, stream, fn x -> Stakeholder.to_json!(x)<>"\n" end)
            |> Stream.run
        else
            err -> err
        end
    end

end