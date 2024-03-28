local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local A = require('telescope-extension-maker.async')

local async, await = A.async, A.await

local once = function(fn)
	local done = false
	return function(...)
		if done then return end
		done = true
		fn(...)
	end
end

local CTX = {}

function CTX:new(opts, ext)
	local ctx = { opts = opts, ext = ext }

	setmetatable(ctx, self)
	self.__index = self

	return ctx
end

function CTX:getResults()
	local ctx = self
	local command = ctx.ext.command

	if type(command) == 'function' then
		local err, results = await(function(callback)
			local cb = once(callback)
			local results = command(cb)
			if results ~= nil then cb(nil, results) end
		end)

		if err then error(tostring(err)) end
		if results == nil then error('The extension command returned nil') end

		return results
	else
		local r = vim.api.nvim_exec(command, true)
		return vim.split(r, '\n')
	end
end

function CTX:refreshPicker(prompt_bufnr, opts)
	local picker = action_state.get_current_picker(prompt_bufnr)

	async(function()
		picker:refresh(self:newFinder(), vim.tbl_extend('keep', opts or {}, { reset_prompt = false }))
	end)()
end

local function filterItems(r, ctx)
	local items = {}
	if type(r[1]) == 'string' then
		for _, text in pairs(r) do --
			if #text == 0 then goto continue end
			items[#items + 1] = { text = text }
			::continue::
		end
	else
		for _, item in pairs(r) do
			if not ctx.displayer then if #item.text == 0 then goto continue end end
			items[#items + 1] = item
			::continue::
		end
	end

	return items
end

local entryMaker = function(displayer)
	return function(item)
		local entry = item.entry or {}

		if displayer then
			entry.display = function()
				return displayer(item.text)
			end
		else
			entry.display = entry.display or item.text
		end

		entry.ordinal = entry.ordinal or item.text

		return entry
	end
end

function CTX:newFinder()
	local ctx = self
	local results = ctx:getResults()
	ctx.items = filterItems(results, ctx)

	return finders.new_table { --
		results = ctx.items,
		entry_maker = entryMaker(ctx.displayer),
	}
end

function CTX:getSelectedItem()
	local selection = action_state.get_selected_entry()
	return self.items[selection.index]
end

return CTX
