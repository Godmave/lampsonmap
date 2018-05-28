---
--- Created by Godmave.
--- DateTime: 15.05.2018 19:29
---
require("config")

colors = {
    ["red"] = {
        map_color = {r = .9, g = .0, b = .0}
    },
    ["green"] = {
        map_color = {r = .0, g = .9, b = .0}
    },
    ["blue"] = {
        map_color = {r = .0, g = .0, b = .9}
    },
    ["yellow"] = {
        map_color = {r = .9, g = .9, b = .0}
    },
    ["pink"] = {
        map_color = {r = .9, g = 0, b = .6}
    },
    ["cyan"] = {
        map_color = {r = 0, g = .9, b = .9}
    },
    ["white"] = {
        map_color = {r = .9, g = .9, b = .9}
    },
    ["grey"] = {
        map_color = {r = .5, g = .5, b = .5}
    },
    ["black"] = {
        map_color = {r = .0, g = .0, b = .0}
    },
    ["default"] = {
        map_color = {r = .2, g = .2, b = .5}
    }
}

base_tile = {
    ageing = 0,
    collision_mask = {
        "ground-tile"
    },
    can_be_part_of_blueprint = false,
    decorative_removal_probability = 0.9,
    layer = 61,
    needs_correction = false,
    type = "tile",
    vehicle_friction_modifier = 1.6,
    walking_speed_modifier = 1.0
}

data.raw["lamp"]["small-lamp"].flags = { "placeable-neutral", "player-creation", "not-on-map" }

--checks if tile collision_mask has ground-tile option of not
function ground_collision_check(collision_mask)
    for _, mask in pairs(collision_mask) do
        if mask == "ground-tile" then
            return true
        end
    end
    return false
end

for color_index, color in pairs(colors) do
    local tile = util.table.deepcopy(base_tile)
    local original_tile = data.raw["tile"][defined_base_tile]
    if not ground_collision_check(original_tile.collision_mask) then
        original_tile = data.raw["tile"][defined_base_tile]
    end
    tile.name = "lamp-" .. defined_base_tile .. "-map-" .. color_index
    tile.map_color = color.map_color
    tile.variants = util.table.deepcopy(original_tile.variants)
    tile.walking_sound = util.table.deepcopy(original_tile.walking_sound)
    data:extend({tile})
end
