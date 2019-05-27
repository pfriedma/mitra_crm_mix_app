defmodule MitraCrm.StakeholderDate do
    alias __MODULE__
    @derive [Poison.Encoder]
    #@enforce_keys [:date, :description, :reminder, :annual]
    defstruct [:date, :description, :reminder, :annual]
   
    defimpl Poison.Decoder, for: StakeholderDate do
        def decode(%{
            date: date, 
            description: description,
            reminder: reminder,
            annual: annual
        }, options) do
            %StakeholderDate{ 
                date: Date.from_iso8601!(date),
                description: description,
                reminder: reminder,
                annual: annual
            }
        end
    end


    def new(date, description, reminder, annual) do
        {:ok, %StakeholderDate{date: date, description: description, reminder: reminder, annual: annual}}
    end

    def new_from_str(date, description, reminder, annual) when is_binary(date) do
        cdate = Date.from_iso8601!(date)
        new(cdate, description, reminder, annual)
    end

    def is_upcoming(date) do
        with reminder_date <- Date.add(Date.utc_today, date.reminder),
             recalc_date <- updated_date(date, reminder_date)
            
        do 
            difference = Date.diff(reminder_date, recalc_date)
            difference <= date.reminder and difference > 0
        end

    end

    defp updated_date(date, reminder_date) do
        case date.annual do
            true -> %Date{date.date | year: reminder_date.year}
            _ -> date.date
        end
    end

end