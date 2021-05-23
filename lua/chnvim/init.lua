---[[----------------------------------------------------------------------]]---
--                                                                            --
--        ___         ___         ___                              ___        --
--       /  /\       /__/\       /__/\        ___      ___        /__/\       --
--      /  /:/       \  \:\      \  \:\      /__/\    /  /\      |  |::\      --
--     /  /:/         \__\:\      \  \:\     \  \:\  /  /:/      |  |:|:\     --
--    /  /:/  ___ ___ /  /::\ _____\__\:\     \  \:\/__/::\    __|__|:|\:\    --
--   /__/:/  /  //__/\  /:/\:/__/::::::::\___  \__\:\__\/\:\__/__/::::| \:\   --
--   \  \:\ /  /:\  \:\/:/__\\  \:\~~\~~\/__/\ |  |:|  \  \:\/\  \:\~~\__\/   --
--    \  \:\  /:/ \  \::/     \  \:\  ~~~\  \:\|  |:|   \__\::/\  \:\         --
--     \  \:\/:/   \  \:\      \  \:\     \  \:\__|:|   /__/:/  \  \:\        --
--      \  \::/     \  \:\      \  \:\     \__\::::/    \__\/    \  \:\       --
--       \__\/       \__\/       \__\/         ~~~~               \__\/       --
--                                                                            --
--                                                                            --
--                      chnvim - Neovim profile switcher                      --
---]]----------------------------------------------------------------------[[---

local vim = vim
local filter = vim.tbl_filter
local utils = require('chnvim.utils')
local log = require('chnvim.utils.log')

---- Variables -----------------------------------------------------------------
--------------------------------------------------------------------------------

local chnvim_version = '0.1.0'
local user_home = os.getenv('HOME')
local config_home =
	(os.getenv('XDG_CONFIG_HOME') or user_home .. '/.config')

local chnvim_profiles_paths = {
	string.format('%s/.nvim_profiles.lua', user_home),
	string.format('%s/%s', config_home, 'chnvim/profiles.lua'),
}
local chnvim_default_profile_paths = {
	string.format('%s/.nvim_profile', user_home),
	string.format('%s/%s', config_home, 'chnvim/profile'),
}

local chnvim_profiles_path = utils.head(filter(utils.file_exists, chnvim_profiles_paths))
	or utils.head(chnvim_profiles_paths)
local chnvim_default_profile_path = utils.head(filter(utils.file_exists, chnvim_default_profile_paths))
	or utils.head(chnvim_default_profile_paths)

local chnvim_profile_name = utils.read_file(chnvim_default_profile_path)[1]
	or 'default'

---- Functions -----------------------------------------------------------------
--------------------------------------------------------------------------------

-- get_profile looks for the profile which is currently in use
-- @return table or nil
local function get_profile()
	local current_profile = {}

	if chnvim_profiles_path == nil then
		log.error('Cannot find profiles file')
		return nil
	else
		-- Load Profiles table
		vim.cmd('luafile ' .. chnvim_profiles_path)
		for name, path in pairs(Profiles) do
			if name == chnvim_profile_name then
				current_profile = {
					name = name,
					path = path,
				}
				break
			end
		end
	end

	return current_profile
end

function Chnvim_load_user_init()
	log.info('Starting version ' .. chnvim_version)
	local current_profile = get_profile()
	local current_profile_path = utils.expand_home(current_profile.path)

	-- Set possible init files for Neovim, defaults to `init.vim`
	local inits = {
		current_profile_path .. '/init.vim',
		current_profile_path .. '/init.lua',
	}
	local init_file = utils.head(filter(utils.file_exists, inits))
		or utils.head(inits)

	-- Check if chnvim should load a Vimscript init or a Lua init
	local init_type = utils.get_file_extension(init_file)

	-- Symlink configuration Vim directories, e.g. autoload
	-- before sourcing the init file
	local nvim_config_path = vim.fn.stdpath('config')
	local nvim_core_dirs = {
		'after',
		'autoload',
		'colors',
		'doc',
		'templates',
		'ftdetect',
		'ftplugin',
		'syntax',
		'plugin',
		'snippets',
		'spell',
	}
	for _, nvim_dir in ipairs(nvim_core_dirs) do
		utils.symlink(
			current_profile_path .. '/' .. nvim_dir,
			nvim_config_path .. '/' .. nvim_dir,
			true,
			{ dir = true }
		)
	end

	--- Symlink also the files at config root, e.g. lv-settings.lua in LunarVim
	--- or doomrc in doom-nvim

	-- Ignore unnecessary files, like README.md, the configs LICENSE and hidden files
	local config_ignore_files = {
		'init.vim',
		'init.lua',
		'LICENSE',
		'*.md',
		'lua',
		table.unpack(nvim_core_dirs),
	}
	local config_extra_files =
		utils.get_files(current_profile_path, config_ignore_files)
	for _, config_file in ipairs(config_extra_files) do
        -- Don't try to symlink directories
        if not utils.file_exists(config_file .. '/') then
            utils.symlink(
                current_profile_path .. '/' .. config_file,
                nvim_config_path .. '/' .. config_file,
                true
            )
        end
	end

	-- Add lua files to Lua's path if there's a lua directory
	if utils.file_exists(current_profile_path .. '/lua/') then
		package.path = current_profile_path
			.. '/lua/?/init.lua;'
			.. current_profile_path
			.. '/lua/?.lua;'
			.. package.path
	end

	-- Source init file
	if init_type:find('lua') then
		vim.cmd('luafile ' .. init_file)
	else
		vim.cmd('source ' .. init_file)
	end

    log.info('Loaded ' .. chnvim_profile_name .. ' profile')
    return
end