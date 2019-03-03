---
--- Created by Godmave.
--- DateTime: 15.05.2018 19:29
---
require "config"


--ColoredLampEntity dictionary (copy of global.lamp_dictionary) sorted by suface names e.g global_lamps_dictionary["surface_name"][unit_number]
global_lamps_dictionary = {}
--ColoredLampEntity that need to be redrawn on map
global_pending_changes = {}
--Remember when the lamp was last added
global_last_added = {}
global_current_tick = nil


function table.removeKey(t, k)
    local i = 0
    local keys, values = {},{}
    for k,v in pairs(t) do
        i = i + 1
        keys[i] = k
        values[i] = v
    end

    while i>0 do
        if keys[i] == k then
            table.remove(keys, i)
            table.remove(values, i)
            break
        end
        i = i - 1
    end

    local a = {}
    for i = 1,#keys do
        a[keys[i]] = values[i]
    end

    return a
end

function on_build_lamp(event_args)
    local created_entity = event_args.created_entity
    if created_entity.name == "small-lamp" then
        local lamp_dictionary_index = created_entity.unit_number
        local lamp_surface_name = created_entity.surface.name
        local old_tile_name = ""
        if global_lamps_dictionary[lamp_surface_name] == nil then
            global_lamps_dictionary[lamp_surface_name] = {}
        end
        if global_lamps_dictionary[lamp_surface_name][lamp_dictionary_index] ~= nil then
            old_tile_name = global_lamps_dictionary[lamp_surface_name][lamp_dictionary_index].tile.original_tile_name
            global_lamps_dictionary[lamp_surface_name][lamp_dictionary_index] = nil
        else
            old_tile_name = created_entity.surface.get_tile(created_entity.position.x, created_entity.position.y).prototype.name
            if string.find(old_tile_name, "lamp") ~= nil then
                local start_of_sequence, end_of_secuence = string.find(old_tile_name, "-map-")
                old_tile_name =  string.sub(old_tile_name, 6, start_of_sequence - 1)
                --print("ha, strange")
            end
        end
        update_lamp_in_dictionary(created_entity, old_tile_name)
    end
end

function on_mined_lamp(event_args)
    local mined_entity = event_args.entity
    if mined_entity.name == "small-lamp" then
        local lamp_dictionary_index = mined_entity.unit_number
        local lamp_position = {mined_entity.position.x, mined_entity.position.y}
        --print(lamp_dictionary_index)
        local lamp_surface_name = mined_entity.surface.name
        if global_lamps_dictionary[lamp_surface_name] == nil then
            error("Something wrong! There is no such lamp in surface " .. lamp_surface_name)
            return
        end
        if global_lamps_dictionary[lamp_surface_name][lamp_dictionary_index] ~= nil then
            local mined_ColoredLampEntity = global_lamps_dictionary[lamp_surface_name][lamp_dictionary_index]
            mined_entity.surface.set_tiles({{ name=mined_ColoredLampEntity.tile.original_tile_name, position=lamp_position}}, true)
            global_lamps_dictionary[lamp_surface_name] = table.removeKey(global_lamps_dictionary[lamp_surface_name], lamp_dictionary_index)
        end
        if global_pending_changes ~= nil and global_pending_changes[lamp_surface_name] ~= nil and global_pending_changes[lamp_surface_name][lamp_dictionary_index] ~= nil then
            global_pending_changes[lamp_surface_name][lamp_dictionary_index] = nil
        end
    end
end

--reads from lamp behavior signals information and returns ir in array for each wire type
function get_virtual_signal(lamp_behavior)
    local result_for_each_wire = {}
    for wire_index,wire in pairs(circuit_wires_types) do
        local circuit_network = lamp_behavior.get_circuit_network(wire)
        if circuit_network ~= nil and circuit_network.signals ~= nil and #circuit_network.signals > 0 then
            local recieved_color_signal = nil
            for virtual_signal_color_name,virtual_signal_color in pairs(virtual_signals) do
                local get_next_signal_result = circuit_network.get_signal({type="virtual",name=virtual_signal_color.name})
                if get_next_signal_result > 0 then
                    recieved_color_signal = virtual_signal_color
                    break
                end
            end
            if recieved_color_signal ~= nil then
                result_for_each_wire[wire] = recieved_color_signal
            end

        end
    end
    return result_for_each_wire
end

function add_lamp_in_pending_queue(unit_number, coloredLampEntity)
    local lamp_surface_name = coloredLampEntity.entity.surface.name
    if global_pending_changes == nil then
        global_pending_changes = {}
        global_pending_changes[lamp_surface_name] = {}
    elseif global_pending_changes[lamp_surface_name] == nil then
        global_pending_changes[lamp_surface_name] = {}
    end
    global_pending_changes[lamp_surface_name][unit_number] = coloredLampEntity
end

function print_table(object)
    for key,value in pairs(object) do
        game.print("found member " .. key .. " with " .. tostring(value))
    end
end


function update_lamp_in_dictionary(entity, old_tile_name)
    if global_last_added[entity.unit_number] and (global_current_tick - global_last_added[entity.unit_number] < 30) then
        return
    end

    global_last_added[entity.unit_number] = global_current_tick


    local lamp_behavior = entity.get_control_behavior()
    local final_color, lamp_surface_name = "default", entity.surface.name
    local oldColor, newColor = {}, {}
    local changed = false

    if lamp_behavior ~= nil and entity.energy > 0 then
        if global_lamps_dictionary[lamp_surface_name][entity.unit_number] ~= nil then
            oldColor = global_lamps_dictionary[lamp_surface_name][entity.unit_number].tile.colorCode
        else
            changed = true
        end

        if lamp_behavior.color ~= nil then
            newColor = lamp_behavior.color

            if oldColor == nil or oldColor.r ~= newColor.r or oldColor.g ~= newColor.g or oldColor.b ~= newColor.b then
                changed = true
            end
        else
            changed = true
        end

        if changed then
            if lamp_behavior.use_colors and lamp_behavior.circuit_condition.fulfilled then
                local circuit_signal_on_wire = get_virtual_signal(lamp_behavior)
                local number_of_founded_networks_with_valid_signal = table_length(circuit_signal_on_wire)
                if number_of_founded_networks_with_valid_signal > 1 then
                    --pick color between two network signals
                    local signal_on_red_wire, signal_on_green_wire = circuit_signal_on_wire[circuit_wires_types[1]], circuit_signal_on_wire[circuit_wires_types[2]]
                    if(signal_on_red_wire.priority < signal_on_green_wire.priority) then
                        final_color = signal_on_red_wire.color
                    else
                        final_color = signal_on_green_wire.color
                    end
                elseif number_of_founded_networks_with_valid_signal == 1 then
                    local _, correct_virtual_signal = next(circuit_signal_on_wire, nil)
                    final_color = correct_virtual_signal.color
                else
                    final_color = "white"
                end
            elseif not lamp_behavior.disabled then
                final_color = "white"
            else
                final_color = "default"
            end

            if global_lamps_dictionary[lamp_surface_name][entity.unit_number] and global_lamps_dictionary[lamp_surface_name][entity.unit_number].tile.color == final_color then
                changed = false
            end
        end
    end

    if global_lamps_dictionary[lamp_surface_name][entity.unit_number] ~= nil then
        if changed then
            global_lamps_dictionary[lamp_surface_name][entity.unit_number].tile.new_tile_name = generate_lamp_tile_name(final_color)
            global_lamps_dictionary[lamp_surface_name][entity.unit_number].tile.color = final_color
            global_lamps_dictionary[lamp_surface_name][entity.unit_number].tile.colorCode = newColor
            add_lamp_in_pending_queue(entity.unit_number, global_lamps_dictionary[lamp_surface_name][entity.unit_number])
        end
    else
        global_lamps_dictionary[lamp_surface_name][entity.unit_number] = ColoredLampEntity(entity, LampTile(entity.position, final_color, newColor, old_tile_name))
        add_lamp_in_pending_queue(entity.unit_number, global_lamps_dictionary[lamp_surface_name][entity.unit_number])

    end
end

function draw_tiles(surface)
    local lua_tile_array = {}
    for index,color in pairs(global_lamps_dictionary[surface.name]) do
        --if color.entity.valid then
        if color.entity.energy > 0 then
            table.insert(lua_tile_array, { name = color.tile.new_tile_name, position = color.entity.position })
        else
            table.insert(lua_tile_array, { name = generate_lamp_tile_name("default"), position = color.entity.position })
        end
        --end
    end
    surface.set_tiles(lua_tile_array, true)
end


--enumerations
--Wire types enum
circuit_wires_types = {
    defines.wire_type.red,
    defines.wire_type.green
}
--Virtual signals enum
virtual_signals = {
    ["red"] = {
        name = "signal-red",
        type = "virtual-signal",
        priority = 1,
        color = "red"
    },
    ["green"] = {
        name = "signal-green",
        type = "virtual-signal",
        priority = 2,
        color = "green"
    },
    ["blue"] = {
        name = "signal-blue",
        type = "virtual-signal",
        priority = 3,
        color = "blue"
    },
    ["yellow"] = {
        name = "signal-yellow",
        type = "virtual-signal",
        priority = 4,
        color = "yellow"
    },
    ["pink"] = {
        name = "signal-pink",
        type = "virtual-signal",
        priority = 5,
        color = "pink"
    },
    ["cyan"] = {
        name = "signal-cyan",
        type = "virtual-signal",
        priority = 6,
        color = "cyan"
    },
    ["white"] = {
        name = "signal-white",
        type = "virtual-signal",
        priority = 7,
        color = "white"
    },
    ["grey"] = {
        name = "signal-grey",
        type = "virtual-signal",
        priority = 8,
        color = "grey"
    },
    ["black"] = {
        name = "signal-black",
        type = "virtual-signal",
        priority = 9,
        color = "black"
    }
}

--LampTile class for item in lamp dictionary
LampTile = {}
LampTile.__index = LampTile
setmetatable(LampTile, {
    __call = function (cls, position, color, colorCode, original_tile_name)
        local self = setmetatable({}, cls)
        self:_init(position, color, colorCode, original_tile_name)
        return self
    end,
})
--LampTile constructor
function LampTile:_init(position, color, colorCode, original_tile_name)
    self.position = position
    self.color = color
    self.colorCode = colorCode
    self.original_tile_name = original_tile_name
    self.new_tile_name = generate_lamp_tile_name(color)
end

--ColoredLampEntity class for item in lamp dictionary
ColoredLampEntity = {}
ColoredLampEntity.__index = ColoredLampEntity
setmetatable(ColoredLampEntity, {
    __call = function (cls, entity, LampTile)
        local self = setmetatable({}, cls)
        self:_init(entity, LampTile)
        return self
    end,
})
--ColoredLampEntity constructor
function ColoredLampEntity:_init(entity, LampTile)
    self.entity = entity
    self.tile = LampTile
end

--helpers functions
function table_length(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end
function table_length_1(T)
    local count, is_same = 0, false
    for _,__t in pairs(T) do
        for ___ in pairs(__t) do
            count = count + 1
        end
    end
    return count
end

function table_length_2(T)
    local count, is_same = 0, false
    for _,__t in pairs(T) do
        for ___, ___t in pairs(__t) do
            for ____ in pairs(___t) do
                count = count + 1
            end
        end
    end
    return count
end

function generate_lamp_tile_name(color_name)
    return "lamp-" .. base_tile .. "-map-" .. color_name
end

function get_surfaces_to_update()
    local only_unique_surfaces = {}
    local result_array = {}
    for player_index, player in pairs(game.players) do
        only_unique_surfaces[player.surface.name] = true
    end
    for surface_name in next, only_unique_surfaces, nil do
        table.insert(result_array, surface_name)
    end
    return result_array
end

function get_forces_to_update()
    local only_unique_forces = {}
    local result_array = {}
    for player_index, player in pairs(game.players) do
        only_unique_forces[player.force.name] = true
    end
    for force_name in next, only_unique_forces, nil do
        table.insert(result_array, force_name)
    end
    return result_array
end

function save_to_global()
    local start_index = nil
    global.lamps_dictionary = nil --make GC know that we don't need old table anymore
    global.lamps_dictionary = {}
    for surface_name,lamps_on_surface in next,global_lamps_dictionary, nil do
        global.lamps_dictionary[surface_name] = {}
        local number_of_iterations = math.ceil(table_length(lamps_on_surface) / 200) --200 objects in array is maximum for factorio serialization mechanism
        for index=1,number_of_iterations do
            local count = 1
            global.lamps_dictionary[surface_name][index] = {}
            for colored_lamp_entity_index, colored_lamp_entity in next,lamps_on_surface, start_index do
                if count > 200 then
                    break
                elseif count == 200 then
                    start_index = colored_lamp_entity_index
                end
                global.lamps_dictionary[surface_name][index][count] =
                {
                    colored_lamp_entity_index,
                    colored_lamp_entity
                }
                count = count + 1
            end
        end
    end
    print("Lamps On Map has been saved")
end

function load_from_global()
    global_lamps_dictionary = nil --make GC know that we don't need old table anymore
    global_lamps_dictionary = {}
    for surface_name, serialized_lamps in next, global.lamps_dictionary, nil do
        global_lamps_dictionary[surface_name] = {}
        for _,chunk_of_data in pairs(serialized_lamps) do
            for _,serialized_colored_lamp_entity in pairs(chunk_of_data) do
                global_lamps_dictionary[surface_name][serialized_colored_lamp_entity[1]] = serialized_colored_lamp_entity[2]
            end
        end
    end
end


function update_all_lamps()
    for index,surface in pairs(game.surfaces) do
        if global_lamps_dictionary[surface.name] == nil then
            global_lamps_dictionary[surface.name] = {}
        end
        local lamp_entities = surface.find_entities_filtered({name = "small-lamp", type = "lamp"})
        for entity_index,entity in pairs(lamp_entities) do
            local lamp_dictionary_index = entity.unit_number
            if global_lamps_dictionary[surface.name][lamp_dictionary_index] ~= nil then
                update_lamp_in_dictionary(entity, global_lamps_dictionary[surface.name][lamp_dictionary_index].tile.original_tile_name)
            else
                local old_tile_name = entity.surface.get_tile(entity.position.x, entity.position.y).prototype.name
                if string.find(old_tile_name, "lamp") ~= nil then
                    local start_of_sequence, end_of_secuence = string.find(old_tile_name, "-map-")
                    old_tile_name =  string.sub(old_tile_name, 6, start_of_sequence - 1)
                end
                update_lamp_in_dictionary(entity, old_tile_name)
            end
        end
        draw_tiles(surface)
    end
end

main_coroutine = function(start_index, surface_name)
    local count = 1

    if not (global_lamps_dictionary and global_lamps_dictionary[surface_name] and table_size(global_lamps_dictionary[surface_name])>0)  then
        return
    end

    for colored_lamp_entity_index, colored_lamp_entity in next,global_lamps_dictionary[surface_name], start_index do
        if count > lamps_per_iteration then break end
        end_index = colored_lamp_entity_index

        if colored_lamp_entity.entity.valid then
            update_lamp_in_dictionary(colored_lamp_entity.entity, colored_lamp_entity.tile.original_tile_name)
        end
        count = count + 1
    end

    if count <= lamps_per_iteration then
        end_index = nil
    end

    return end_index
end

draw_coroutine = function(lamps_for_update, surface_name)
    if lamps_for_update ~= nil then
        local lua_tile_array = {}
        for _, colored_lamp in pairs(lamps_for_update) do
            if colored_lamp.entity.valid then
                table.insert(lua_tile_array, { name = colored_lamp.tile.new_tile_name, position = colored_lamp.tile.position })
            end
        end
        game.surfaces[surface_name].set_tiles(lua_tile_array, false)
    end
end

lastLampIndexed = 1
function on_regular_checking(event_args)
    global_current_tick = event_args.tick
    if event_args.tick % iteration_frequency == 0 then
        for _, surface_name in next, get_surfaces_to_update(), nil do
            lastLampIndexed = main_coroutine(lastLampIndexed, surface_name)
        end
    elseif event_args.tick % (iteration_frequency + 1) == 0 then
        for _, surface_name in next, get_surfaces_to_update(), nil do
            if global_pending_changes[surface_name] ~= nil then
                draw_coroutine(global_pending_changes[surface_name], surface_name)
                global_pending_changes[surface_name] = {}
            end
        end
    elseif event_args.tick % 2001 == 0 then
        save_to_global()
    end
end


function on_initialize()
    base_tile = defined_base_tile
    iteration_frequency = defined_iteration_frequency
    lamps_per_iteration = defined_lamps_per_iteration

    if global.lamps_dictionary ~= nil then
        local all_lamps_quantity, quantity_of_lamps_in_dictionary = 0, table_length_2(global.lamps_dictionary)
        for index,surface in pairs(game.surfaces) do
            all_lamps_quantity = all_lamps_quantity + surface.count_entities_filtered({name = "small-lamp", type = "lamp"})
        end

        if quantity_of_lamps_in_dictionary ~= all_lamps_quantity then
            update_all_lamps()
        else
            load_from_global()
        end
    else
        global.lamps_dictionary = {}
        update_all_lamps()
    end

    script.on_event(defines.events.on_tick, nil)
    script.on_event(defines.events.on_tick, on_regular_checking)
end


script.on_event(defines.events.on_built_entity, on_build_lamp)
script.on_event(defines.events.on_robot_built_entity, on_build_lamp)
script.on_event(defines.events.on_pre_player_mined_item, on_mined_lamp)
script.on_event(defines.events.on_robot_pre_mined, on_mined_lamp)
script.on_event(defines.events.on_tick, on_initialize)
script.on_event(defines.events.on_entity_died, on_mined_lamp)
script.on_event(defines.events.on_player_joined_game, on_player_joined)
