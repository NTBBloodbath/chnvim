-- logger.lua
--
-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
-- Modified _again_ by NTBBloodbath
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.

-- User configuration section
local default_config = {
	-- Name of the plugin. Prepended to log messages.
	plugin = "CHEOVIM-v0.3",

	-- Should print the output to neovim while running.
	use_console = true,

	-- Should highlighting be used in console, see ':h vim.log.levels'.
	highlights = true,

	-- Should write to a file.
	use_file = true,

	-- Any messages above this level will be logged.
	level = "info",

	-- Level configuration.
	modes = {
		{ name = "trace", hl = vim.log.levels.TRACE },
		{ name = "debug", hl = vim.log.levels.DEBUG },
		{ name = "info", hl = vim.log.levels.INFO },
		{ name = "warn", hl = vim.log.levels.WARN },
		{ name = "error", hl = vim.log.levels.ERROR },
		{ name = "fatal", hl = vim.log.levels.ERROR },
	},

	-- Can limit the number of decimals displayed for floats.
	float_precision = 0.01,
}

-- {{{ NO NEED TO CHANGE
local log = {}

local unpack = unpack or table.unpack

log.new = function(config, standalone)
	config = vim.tbl_deep_extend("force", default_config, config)

	local outfile = string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "cache" }), config.plugin)

	local obj
	if standalone then
		obj = log
	else
		obj = {}
	end

	local levels = {}
	for i, v in ipairs(config.modes) do
		levels[v.name] = i
	end

	local round = function(x, increment)
		increment = increment or 1
		x = x / increment
		return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
	end

	local make_string = function(...)
		local t = {}
		for i = 1, select("#", ...) do
			local x = select(i, ...)

			if type(x) == "number" and config.float_precision then
				x = tostring(round(x, config.float_precision))
			elseif type(x) == "table" then
				x = vim.inspect(x)
			else
				x = tostring(x)
			end

			t[#t + 1] = x
		end
		return table.concat(t, " ")
	end

	local console_output = vim.schedule_wrap(function(level_config, info, nameupper, msg)
		local console_lineinfo = vim.fn.fnamemodify(info.short_src, ":t") .. ":" .. info.currentline
		local console_string = string.format("[%-6s%s] %s: %s", nameupper, os.date("%H:%M:%S"), console_lineinfo, msg)

		local split_console = vim.split(console_string, "\n")
		for _, v in ipairs(split_console) do
			if config.highlights and level_config.hl then
  			vim.notify(string.format("[%s] %s", config.plugin, vim.fn.escape(v, '"')), level_config.hl)
  		else
  			vim.notify(string.format("[%s] %s", config.plugin, vim.fn.escape(v, '"')))
  		end
		end
	end)

	local log_at_level = function(level, level_config, message_maker, ...)
		-- Return early if we're below the config.level
		if level < levels[config.level] then
			return
		end
		local nameupper = level_config.name:upper()

		local msg = message_maker(...)
		local info = debug.getinfo(2, "Sl")
		local lineinfo = info.short_src .. ":" .. info.currentline

		-- Output to console
		if config.use_console then
			console_output(level_config, info, nameupper, msg)
		end

		-- Output to log file
		if config.use_file then
			local fp = io.open(outfile, "a")
			local str = string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
			fp:write(str)
			fp:close()
		end

		return ...
	end

	for i, x in ipairs(config.modes) do
		obj[x.name] = function(...)
			return log_at_level(i, x, make_string, ...)
		end

		obj[("fmt_%s"):format(x.name)] = function()
			return log_at_level(i, x, function(...)
				local passed = { ... }
				local fmt = table.remove(passed, 1)
				local inspected = {}
				for _, v in ipairs(passed) do
					table.insert(inspected, vim.inspect(v))
				end
				return string.format(fmt, unpack(inspected))
			end)
		end
	end

	return obj
end

log.new(default_config, true)
-- }}}

return log
