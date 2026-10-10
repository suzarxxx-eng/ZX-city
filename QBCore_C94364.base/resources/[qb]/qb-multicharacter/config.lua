Config = {}

-- Scene: Maze Bank Tower rooftop helipad. The camera looks EAST so the whole downtown skyline is behind the character.
-- The ped faces the camera (CamHeading + 180). Tweak coords if the framing is not what you want.
Config.PedCoords = vector4(-75.0, -818.0, 326.18, 90.0)               -- Preview ped (heading 90 = facing west, towards the camera)
Config.CamHeading = 270.0                                             -- Direction the camera looks (270 = east, towards downtown)
Config.CamDistance = { far = 4.4, near = 1.0 }                        -- Camera distance at zoom 0 (full body) / zoom 1 (face)
Config.CamHeight = { far = 0.55, near = 0.72 }                        -- Camera height above ped feet at zoom 0 / 1
Config.HiddenCoords = vector4(-70.0, -810.0, 326.18, 91.0454)         -- Where your real ped waits (invisible) so the roof stays loaded
Config.Scenes = {                                                     -- Time-of-day options shown in the UI (first = default)
    { id = 'sunset', label = 'غروب', hour = 18, minute = 40, weather = 'EXTRASUNNY' },
    { id = 'day',    label = 'نهار', hour = 12, minute = 0,  weather = 'EXTRASUNNY' },
    { id = 'night',  label = 'ليل',  hour = 23, minute = 0,  weather = 'CLEAR' },
}

Config.DefaultSpawn = vector3(-1035.71, -2731.87, 12.86)              -- Default spawn coords if you have start apartments disabled
Config.EnableDeleteButton = true                                      -- Define if the player can delete the character or not
Config.customNationality = false                                      -- Defines if Nationality input is custom of blocked to the list of Countries
Config.SkipSelection = false                                          -- Skip the spawn selection and spawns the player at the last location

Config.DefaultNumberOfCharacters = 1                                  -- ONE character per player
Config.PlayersNumberOfCharacters = {                                  -- Optional per-license override (rockstar license from the players table)
    -- { license = 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', numberOfChars = 2 },
}
