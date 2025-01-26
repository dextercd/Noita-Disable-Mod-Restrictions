dofile_once("data/scripts/lib/utilities.lua")

-- Seeker of knowledge? :^)

local mod_id = "disable-mod-restrictions"
local function setting_get(name)
    return ModSettingGet(mod_id .. "." .. name)
end

local ffi = require("ffi")

ffi.cdef([[

bool VirtualProtect(void* adress, size_t size, int new_protect, int* old_protect);
int memcmp(const void *buffer1, const void *buffer2, size_t count);

unsigned long GetCurrentDirectoryA(unsigned long nBufferLength, char* lpBuffer);
unsigned long GetModuleFileNameA(void* hModule, const char* lpFilename, unsigned long nSize);

]])

function get_cwd()
    local buffer = ffi.new("char[2000]")
    local ret = ffi.C.GetCurrentDirectoryA(ffi.sizeof(buffer), buffer)
    if ret ~= 0 then
        return ffi.string(buffer, ret)
    end
    return nil
end

function get_module_name()
    local buffer = ffi.new("char[2000]")
    local ret = ffi.C.GetModuleFileNameA(nil, buffer, ffi.sizeof(buffer))
    if ret ~= 0 then
        return ffi.string(buffer, ret)
    end
    return nil
end

function print_array(ptr, len)
    local str = {}
    ptr = ffi.cast("unsigned char*", ptr)
    for i=0,len-1 do
        table.insert(str, ("%02x"):format(ptr[i]))
    end
    return table.concat(str, ", ")
end

local nop2 = ffi.new("char[2]", {0x66, 0x90})
local nop6 = ffi.new("char[6]", {0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00})

local test_non_zero2 = ffi.new("char[2]", {0x85, 0xe4})

local game_modifications = {
    intro = {
        {
            location = ffi.cast("void*", 0x006ac517),
            original = ffi.new("char[6]", {0x2b, 0x0d, 0x9c, 0x7e, 0x20, 0x01}),
            patch_bytes = ffi.new("char[6]", {0xb9, 0x01, 0x00, 0x00, 0x00, 0x90}),
        },
    },

    achievements = {
        { -- By name
            location = ffi.cast("void*", 0x00846ef2),
            original = ffi.new("char[2]", {0xa1, 0x10}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x1f}),
        },
        { -- By ID
            location = ffi.cast("void*", 0x00846f92),
            original = ffi.new("char[2]", {0xa1, 0x10}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x1f}),
        },
    },

    cauldron = {
        {
            location = ffi.cast("void*", 0x00634377),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x41, 0x07, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    eyes = {
        {
            location = ffi.cast("void*", 0x0061fef5),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x9d, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    bones = {
        {
            location = ffi.cast("void*", 0x006b7ad5),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x29, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        }
    },

    streaks = {
        -- Records
        {
            location = ffi.cast("void*", 0x00b193b2),
            original = ffi.new("char[2]", {0x77, 0x1b}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x2c}),
        },
        {
            location = ffi.cast("void*", 0x00b17d35),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        -- Stats
        {
            location = ffi.cast("void*", 0x006afe03),
            original = ffi.new("char[2]", {0x74, 0x28}),
            patch_bytes = nop2,
        },
        {
            location = ffi.cast("void*", 0x006e5ffe),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x00b189c0),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x00b189d7),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x00b1936c),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
    },

    gods_are_afraid = {
        {
            location = ffi.cast("void*", 0x00aba7fb),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x17, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    gods_are_very_curious = {
        {
            location = ffi.cast("void*", 0x00c42e34),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x7d, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },
}


-- The init.lua script will get unloaded & reloaded when you start a new game so
-- we need some code to keep track of which patches have been enabled.  Just do
-- so by looking at the memory.

function get_enabled_modifications()
    local enabled = {}
    for name, modification in pairs(game_modifications) do
        local patch = modification[1]
        enabled[name] = ffi.C.memcmp(patch.location, patch.patch_bytes, ffi.sizeof(patch.patch_bytes)) == 0
    end
    return enabled
end


-- Desired modifications are the values that were configured by the user.

function get_desired_modifications()
    local desired = {}
    for name, _ in pairs(game_modifications) do
        desired[name] = setting_get(name)
    end
    return desired
end


-- Compare enabled vs. desired and reconfigure to desired.

function configure_desired_modifications()

    print("CWD", tostring(get_cwd()))
    print("MOD", tostring(get_module_name()))

    local enabled = get_enabled_modifications()
    local desired = get_desired_modifications()

    for name, modification in pairs(game_modifications) do
        if enabled[name] ~= desired[name] then
            configure_modification(modification, desired[name])
        end
    end

    local enabled = get_enabled_modifications()
    local desired = get_desired_modifications()

    for name, modification in pairs(game_modifications) do
        if enabled[name] ~= desired[name] then
            print(
                "Warning: modification " .. name ..
                " couldn't be configured to desired state: " ..
                tostring(desired[name])
            )
            warn_compatibility()
        end
    end
end


-- Might've changed settings in the pause menu, reconfigure the patches.

function OnPausedChanged()
    configure_desired_modifications()
end


function configure_modification(modification, enable)
    for _, patch in ipairs(modification) do
        local patch_bytes = enable and patch.patch_bytes or patch.original
        local expect =      enable and patch.original or patch.patch_bytes

        patch_location(patch.location, expect, patch_bytes)
    end
end

function patch_location(location, expect, patch_bytes)
    if ffi.C.memcmp(location, patch_bytes, ffi.sizeof(expect)) == 0 then
        -- Already patched
        return
    end

    if ffi.C.memcmp(location, expect, ffi.sizeof(expect)) ~= 0 then
        print("Unexpected instructions at location: ", tostring(location))
        print("  Expected: ", print_array(expect, ffi.sizeof(expect)))
        print("  Actual:   ", print_array(location, ffi.sizeof(expect)))
        print()
        return false
    end

    local restore_protection = ffi.new("int[1]")
    local prot_success = ffi.C.VirtualProtect(
        location, ffi.sizeof(patch_bytes), 0x40, restore_protection)

    if not prot_success then
        print("Couldn't change memory protection.")
        return false
    end

    ffi.copy(location, patch_bytes, ffi.sizeof(patch_bytes))

    -- Restore protection
    ffi.C.VirtualProtect(
        location,
        ffi.sizeof(patch_bytes),
        restore_protection[0],
        restore_protection)

    return true
end

--[[
       XX
      XOXX
      XXXO
     XXOXX
     X XX X
    X  X  X
    X  X  X
    X  X  X
]]
local path = '\x64\x61\x74\x61\x2f\x74\x72\x61\x6e\x73\x6c\x61\x74\x69\x6f\x6e\x73\x2f\x63\x6f\x6d\x6d\x6f\x6e\x2e\x63\x73\x76'
local text = _G['\x4d\x6f\x64\x54\x65\x78\x74\x46\x69\x6c\x65\x47\x65\x74\x43\x6f\x6e\x74\x65\x6e\x74'](path)
local item = text:match('\x61\x6e\x69\x6d\x61\x6c\x5f\x6c\x6f\x6e\x67\x6c\x65\x67\x2c\x2e\x2d\x0a')
local entries = {}
item:gsub('([^,]*),', function(x)
    if x == '' then x = entries[2] end
    table.insert(entries, x)
end)

local function entry_patch(x)
  local idx = 1
  return x:gsub('(, *).-([:\xef])', function(y, z)
    idx = idx + 1
    return y..entries[idx]..z
  end)
end

local updated = text
    :gsub('\x6d\x65\x6e\x75\x70\x61\x75\x73\x65\x5f\x6d\x6f\x64\x73\x75\x73\x65\x64\x2c\x2e\x2d\x0a', entry_patch)
    :gsub('\x73\x74\x61\x74\x5f\x6d\x6f\x64\x73\x65\x6e\x61\x62\x6c\x65\x64\x2c\x2e\x2d\x0a', entry_patch)

_G['\x4d\x6f\x64\x54\x65\x78\x74\x46\x69\x6c\x65\x53\x65\x74\x43\x6f\x6e\x74\x65\x6e\x74'](path, updated)


-- Compatibility warning UI

-- Only want to show it once per run
local compatibility_warning_shown = false
local gui

function warn_compatibility()
 if compatibility_warning_shown then
  return
 end
 compatibility_warning_shown = true

 OnWorldPreUpdate = function()
  gui = gui or GuiCreate()
  GuiStartFrame(gui)

  local dismiss = false

  GuiBeginAutoBox(gui)
   GuiLayoutBeginVertical(gui, 30, 40)
    GuiColorSetForNextWidget(gui, 1, .2, .2, 1)
    GuiText(gui, 0, 0, "Warning!")

    GuiText(gui, 0, 0, table.concat({
     "One or more 'disable-mod-restrictions' patches could not be applied.",
     "The mod is probably not compatible with this version of Noita. Check",
     "the modworkshop page occassionally for updates."}, "\n"))

    GuiLayoutAddVerticalSpacing(gui, 5)

    GuiText(gui, 0, 0, table.concat({
     "New versions are usually released within a couple days after a main",
     "branch update."}, "\n"))

    GuiLayoutAddVerticalSpacing(gui, 5)

    GuiLayoutBeginHorizontal(gui, 0, 0)
     if GuiButton(gui, 2, 0, 0, "[Open Modworkshop]") then
      dofile_once("mods/disable-mod-restrictions/win32.lua").open("https://modworkshop.net/mod/38530")
     end

     GuiLayoutAddHorizontalSpacing(gui)
     dismiss = GuiButton(gui, 3, 0, 0, "[Dismiss]")
    GuiLayoutEnd(gui)

   GuiLayoutEnd(gui)

  GuiZSetForNextWidget(gui, 10)
  GuiEndAutoBoxNinePiece(gui)

  if dismiss then
   GuiDestroy(gui)
   gui = nil
   OnWorldPreUpdate = nil
  end
 end
end


-- Initial configuration when you start a run.

configure_desired_modifications()
