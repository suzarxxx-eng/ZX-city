const mockRadialData = {
  state: "show",
  menuKeyBind: "F1",
  data: [
    {
      id: "citizen",
      title: "Citizen",
      icon: "#citizen-action",
      close: false,
      items: [
        {
          id: "police:SeatVehicle",
          title: "Seat Nearest",
          icon: "#general-put-in-veh",
          close: true,
          functiontype: "client",
          functionName: "police:client:PutPlayerInVehicle",
          functionParameters: null
        },
        {
          id: "police:UnseatVehicle",
          title: "Unseat Nearest",
          icon: "#police-radioout",
          close: true,
          functiontype: "client",
          functionName: "police:client:SetPlayerOutVehicle",
          functionParameters: null
        },
        {
          id: "police:Carry",
          title: "Carry",
          icon: "#cuffs-carry",
          close: true,
          functiontype: "client",
          functionName: "police:client:CarryPlayer",
          functionParameters: null
        },
        {
          id: "police:Escort",
          title: "Escort",
          icon: "#general-escort",
          close: true,
          functiontype: "client",
          functionName: "police:client:EscortPlayer",
          functionParameters: null
        }
      ]
    },
    {
      id: "EmoteMenu",
      title: "Emote Menu",
      icon: "#general-emotes2",
      close: true,
      functiontype: "client",
      functionName: "emotes:openMenu",
      functionParameters: null
    },
    {
      id: "JobMenu",
      title: "Job Menu",
      icon: "#general-jobmenu",
      close: true,
      functiontype: "client",
      functionName: "multijob:openUI",
      functionParameters: null
    },
    {
      id: "blips",
      title: "Blips",
          description: "Place where u can fix ur hair",
      icon: "#blips",
      close: false,
      items: [
        {
          id: "blips:gas",
          title: "Gas Station",
          icon: "#blips-gasstations",
          close: true,
          functiontype: "client",
          functionName: "qb-fuel:client:showblip",
          functionParameters: null
        },
        {
          id: "blips:clothing",
          title: "Clothing Shop",
          icon: "#house-setoutift",
          close: true,
          functiontype: "client",
          functionName: "qb-clothing:client:showblip",
          functionParameters: "clothing"
        },
        {
          id: "blips:tatto",
          title: "Tattoo Shop",
          icon: "#blips-tattooshop",
          close: true,
          functiontype: "client",
          functionName: "qb-clothing:client:showblip",
          functionParameters: "tattoo"
        },
        {
          id: "blips:barber",
          title: "Barber Shop",
          icon: "#blips-barbershop",
          close: true,
          functiontype: "client",
          functionName: "qb-clothing:client:showblip",
          functionParameters: "barber"
        },
        {
          id: "blips:create",
          title: "Create Blip",
          icon: "#map-pin",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        },
        {
          id: "blips:home",
          title: "Home",
          icon: "#house",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        },
        {
          id: "blips:tire",
          title: "Tire",
          icon: "#tire",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        },
        {
          id: "blips:key",
          title: "House Givekey",
          icon: "#house-givekey",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        },
        {
          id: "blips:lock-open",
          title: "House Resetlock",
          icon: "#house-resetlock",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        },
        {
          id: "blips:decorate",
          title: "House Decorate",
          icon: "#house-decorate",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        },
        {
          id: "blips:houseSetstash",
          title: "House Setstash",
          icon: "#house-setstash",
          close: true,
          functiontype: "client",
          functionName: "mt-createblip/cl/openBlipsMenu",
          functionParameters: null
        }
      ]
    },
    {
      id: "vehicle",
      title: "Vehicle",
      icon: "#vehicle-options",
      close: true,
      functiontype: "client",
      functionName: "vehiclecontrol:toggle",
      functionParameters: null
    },
    {
      id: "RobPlayer",
      title: "Rob Player",
      icon: "#police-search",
      close: true,
      functiontype: "client",
      functionName: "police:client:RobPlayer",
      functionParameters: null
    },
    {
      id: "GiveVehicleKeys",
      title: "Give Key",
      icon: "#vehicle-givekeys",
      close: true,
      functiontype: "client",
      functionName: "vehiclekeys:client:GiveKeys",
      functionParameters: null
    }
  ]
};