# MitraCrm

A lightweight CRM application

## Documentation

[ExDoc Pages](https://pfriedma.github.io/mitra_crm_mix_app/Mitra_CRM_Mix_App/api-reference.html)
## Installation

## Examples

### Running
 ```       
iex(2)> alias MitraCrm.Crm
MitraCrm.Crm
iex(3)> {:ok, pid} = Crm.start_link
iex(3)> {:ok, pid} = Crm.start_link(42, "/tmp/persistance.json", :file)
```

### Add Stakeholder
```
iex(4)> Crm.add_stakeholder(pid, [given_name: "John", family_name: "Smith"])
[
  %MitraCrm.Stakeholder{
    attributes: %{},
    concerns: [],
    contact_information: %{},
    dates: [],
    meta: %MitraCrm.StakeholderMetadata{
      crm_uids: [nil],
      persistance_type: :json,
      persistance_uri: "",
      shared: false,
      updated_date: #DateTime<2019-05-27 20:15:58.761394Z>,
      uuid: "urn:uuid:3d9f812e-80bc-11e9-a21d-b8f6b118cc7d"
    },
    name: %MitraCrm.StakeholderName{
      family_name: "Smith",
      given_name: "John", 
      middle_initial: nil,
     ...
]

## Get stakeholder by uuid
iex(5)> {:ok, test_stakeholder} = Crm.get_stakeholder_by_uuid(pid, "urn:uuid:dcf19ca8-80bc-11e9-a433-b8f6b118cc7d")
{:ok,
 %MitraCrm.Stakeholder{ ...
```

### Engagements
```
## What types of engagements are configured?
iex(6)> Crm.get_engagement_types(pid)
[
  %MitraCrm.EngagementType{
    description: "An in-person engagement",
    engagement_type: "In Person"
  },
  %MitraCrm.EngagementType{
    description: "A telephine call",
    engagement_type: "Phone Call"
  },
  %MitraCrm.EngagementType{description: "An email", engagement_type: "Email"},
  %MitraCrm.EngagementType{
    description: "A work pacakge",
    engagement_type: "Action Item / Deliverable"
  }
]

## Let's add one...
iex(7)> Crm.add_new_engagement(pid, test_stakeholder, "Meet John for Coffee", "In Person", "2019-01-01")  

## It happened well beyond 10 days in the past
iex(9)> {count, stakeholders} = Crm.get_neglected_stakeholders(pid, 10, 10)
{1, [...]}

## Let's try saying 400 days ago is OK :P 
iex(10)> {count, stakeholders} = Crm.get_neglected_stakeholders(pid, 400, 10)
{0, []}

## Let's add a new one more recently...

 iex(14)> Crm.add_new_engagement(pid, test_stakeholder, "Call John", "Phone Call", "2019-05-30")
...

iex(15)> {count, stakeholders} = Crm.get_neglected_stakeholders(pid, 10, 10)                        
{0, []}

```

### Dates and Attributes
```
iex(1)> {:ok, test_stakeholder} = Crm.get_stakeholder_by_uuid(pid, "urn:uuid:dcf19ca8-80bc-11e9-a433-b8f6b118cc7d")
...
iex(2)> {:ok, updated_stakeholder} = MitraCrm.Stakeholder.new_date(test_stakeholder, "1954-04-04", "Birthday", 14, true)
...

iex(14)> Crm.upadte_stakeholder(pid, updated_stakeholder)

iex(15)> {:ok, test_stakeholder} = Crm.get_stakeholder_by_uuid(pid, "urn:uuid:dcf19ca8-80bc-11e9-a433-b8f6b118cc7d")

iex(16)> test_stakeholder.dates                                                                                     
[
  %MitraCrm.StakeholderDate{
    annual: true,
    date: ~D[1954-04-04],
    description: "Birthday",
    reminder: 14
  }
]

MitraCrm.Stakeholder.update_attributes(test_stakeholder, "Favorite Food", ["pizza"])
{:ok,
 %MitraCrm.Stakeholder{
   attributes: %{"Favorite Food" => ["pizza"]},
   ...
```

### Persistance with :file
```

iex(1)> alias MitraCrm.Crm                                                                            
MitraCrm.Crm
iex(2)> {:ok, pid} = Crm.start_link(42, "/tmp/persistance.json", :file)                  
{:ok, #PID<0.471.0>}

iex(3)> Crm.load_state_proc(pid)
{:ok}

iex(4)> {:ok, test_stakeholder} = Crm.get_stakeholder_by_uuid(pid, "urn:uuid:dcf19ca8-80bc-11e9-a433-b8f6b118cc7d")                   

iex(7)> Crm.persist_state_pid(pid)                 
:ok
```