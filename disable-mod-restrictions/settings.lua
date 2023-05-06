dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "disable-mod-restrictions"

local modifications = {
    {
        key = "intro",
        name = "Intro sequence",
        description = "Remove check that prevents the intro sequence from playing.",
    },

    {
        key = "records",
        name = "Records",
        description = "Track new gameplay records such as time, gold, max hp, etc..",
    },
    {
        key = "streaks",
        name = "Track streaks",
        description = "Track win streaks and display them on the game over screen.",
    },

    {
        key = "achievements",
        name = "Steam Achievements",
        description = "Get Steam Achievements despite having mods active.",
        --[[
        You cheated not only the game, but yourself.

        You didn't grow.
        You didn't improve.
        You took a shortcut and gained nothing.

        You experienced a hollow victory.
        Nothing was risked and nothing was gained.

        It's sad that you don't know the difference.

        ↑↑↑ lol, imagine actually thinking this way ↑↑↑
        Just play the game however you want and have fun!
        ]]
    },

    {
        key = "bones",
        name = "Create new bones files. (new wands for Ghosts/Apparitions)",
        description = "Allow bones files to be created while having mods active.",
        disclaimer = "This will cause ghosts to spawn with incomplete wands if you later disable mods that add spells.",
    },

    {
        key = "gods_are_afraid",
        name = ">1 Million damage message",
        description = "Enables 'The Gods are afraid' message and achievement when you do over 1 million damage."
    },

    {
        key = "gods_are_very_curious",
        name = "Negative health message",
        description = "Enables the 'The Gods are very curious' message when your health is below zero.",
    },

    {
        key = "cauldron",
        name = "Cauldron secret",
        description = "Allows the Cauldron to spawn into the world.",
        spoiler = true,
    },
    {
        key = "eyes",
        name = "Eyes secret",
        description = "Re-enable the encrypted eye messages.",
        spoiler = true,
    },
}

mod_settings = {}

function populate_mod_settings(reveal_spoilers)
    function spoiler_name(name)
        return name:sub(1, 1) .. string.rep("x", #name - 1)
    end

    function spoiler_description(desc)
        return "Reveal spoilers for more details."
    end

    function mod_settings_entry(attributes)
        local spoiler = (attributes.spoiler and not reveal_spoilers)
        local name = spoiler and spoiler_name(attributes.name) or attributes.name
        local description = spoiler and spoiler_description(attributes.description) or attributes.description

        return {
            id = attributes.key,
            ui_name = name,
            ui_description = description,
            value_default = true,
            scope = MOD_SETTING_SCOPE_RUNTIME,
        }
    end

    function mod_disclaimer_entry(attributes)
        local disclaimer = spoiler and spoiler_description(attributes.disclaimer) or attributes.disclaimer
        return {
            id = "_",
            ui_name = "  Warning!",
            ui_description = attributes.disclaimer,
            not_setting = true,
            ui_fn = function(mod_id, gui, in_main_menu, im_id, setting)
                GuiColorSetForNextWidget(gui, 1.0, 0.4, 0.4, 1.0)
                GuiText(gui, mod_setting_group_x_offset, 0, setting.ui_name)
                mod_setting_tooltip(mod_id, gui, in_main_menu, setting)
            end
        }
    end

    mod_settings = {}
    spoilers_group = {
        category_id = "spoilered_modifications",
        ui_name = "Spoilers",
        ui_description = "These settings may contain spoilers",
        settings = {
            {
                id = "reveal_spoilers",
                ui_name = "Reveal spoilers",
                ui_description = "",
                ui_fn = function(mod_id, gui, in_main_menu, im_id, setting)
                    if GuiButton(gui, im_id, mod_setting_group_x_offset, 0, "[Reveal spoilers]") then
                        populate_mod_settings(true)
                    end
                end,
                not_setting = true,
            },
        }
    }

    for _, attributes in ipairs(modifications) do
        local active_group = attributes.spoiler and spoilers_group.settings or mod_settings
        table.insert(active_group, mod_settings_entry(attributes))

        if attributes.disclaimer then
            table.insert(active_group, mod_disclaimer_entry(attributes))
        end
    end

    table.insert(mod_settings, spoilers_group)
end

function ModSettingsUpdate(init_scope)
    mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
    return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end

populate_mod_settings(false)
