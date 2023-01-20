-- telescope extension tools
local telescope = require('telescope')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local action_utils = require 'telescope.actions.utils'
local sorters = require('telescope-extension-maker.sorters')
local previewers = require('telescope-extension-maker.previewers')
local entry_display = require('telescope.pickers.entry_display')
local A = require('telescope-extension-maker.async')

local M = {}

local async, await = A.async, A.await
local set_hl = vim.api.nvim_set_hl

-- @class EntryOpts
-- :h telescope.make_entry
--
-- Options:
-- - value any: value key can be anything but still required
-- - valid bool: is an optional key because it defaults to true but if the key is
--   set to false it will not be displayed by the picker. (optional)
-- - ordinal string: is the text that is used for filtering (required)
-- - display string|function: is either a string of the text that is being
--   displayed or a function receiving the entry at a later stage, when the entry
--   is actually being displayed. A function can be useful here if complex
--   calculation have to be done. `make_entry` can also return a second value a
--   highlight array which will then apply to the line. Highlight entry in this
--   array has the following signature `{ { start_col, end_col }, hl_group }`
--   (required).
-- - filename string: will be interpreted by the default `<cr>` action as open
--   this file (optional)
-- - bufnr number: will be interpreted by the default `<cr>` action as open this
--   buffer (optional)
-- - lnum number: lnum value which will be interpreted by the default `<cr>`
--   action as a jump to this line (optional)
-- - col number: col value which will be interpreted by the default `<cr>` action
--   as a jump to this column (optional)

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

local function newFinder(ctx)
	local results = ctx.getResults()
	ctx.items = filterItems(results, ctx)

	return finders.new_table { --
		results = ctx.items,
		entry_maker = entryMaker(ctx.displayer),
	}
end

local function setKeymaps(ctx)
	return function(prompt_bufnr, map)
		local ext, items = ctx.ext, ctx.items

		if ext.onSubmit then
			actions.select_default:replace(function()
				local selections = {}
				action_utils.map_selections(prompt_bufnr, function(selection)
					local item = items[selection.index]
					table.insert(selections, item)
				end)

				actions.close(prompt_bufnr)

				if #selections == 1 then
					ext.onSubmit(selections[1])
				elseif #selections > 1 then
					ext.onSubmit(selections)
				else
					local selection = action_state.get_selected_entry()
					ext.onSubmit(items[selection.index])
				end
			end)
		end

		if ext.refreshKey then
			map({ 'i', 'n' }, ext.refreshKey, function()
				local picker = action_state.get_current_picker(prompt_bufnr)
				async(function()
					picker:refresh(newFinder(ctx), { reset_prompt = false })
				end)()
			end)
		end

		return true
	end
end

local once = function(fn)
	local done = false
	return function(...)
		if done then return end
		done = true
		fn(...)
	end
end

-- @param userOpts {table} user config of telescope extension
-- @param ext {MakerExtension}
local extCallback = function(userOpts, ext)
	local opts = vim.tbl_extend('keep', userOpts or {}, ext.picker)

	opts = vim.tbl_extend('keep', opts, {
		default_selection_index = 1,
		prompt_title = ext.name,
		preview_title = 'Preview',
		previewer = false,
		sorter = 'generic',
		wrap_results = true,
	})

	local ctx = { opts = opts, ext = ext }

	if ext.format then ctx.displayer = entry_display.create(ext.format) end

	local previewer = opts.previewer
	if type(previewer) == 'string' then opts.previewer = previewers.get(previewer) end

	local sorter = opts.sorter
	if type(sorter) == 'string' then opts.sorter = sorters.get(sorter) end

	local command = ext.command

	if type(command) == 'function' then
		ctx.getResults = function()
			local err, results = await(function(callback)
				local cb = once(callback)
				local results = command(cb)
				if results ~= nil then cb(nil, results) end
			end)

			if err then error(tostring(err)) end
			if results == nil then error('The extension command returned nil') end
			return results
		end
	else
		ctx.getResults = function()
			local r = vim.api.nvim_exec(command, true)
			return vim.split(r, '\n')
		end
	end

	opts.finder = newFinder(ctx)

	local selIdx = opts.default_selection_index
	if selIdx < 0 then opts.default_selection_index = #ctx.items + 1 + selIdx end

	opts.attach_mappings = setKeymaps(ctx)

	-- https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#first-picker
	pickers.new(opts):find()
end

-- @class Item {table}
-- @prop text {string|table}
-- @prop [entry] {EntryOpts}
-- @prop [<any-key> = <any-value>] -- You can set any key/value pairs into item

-- @class PickerOptions {table}
--   The telescope picker options.
--   See https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#picker
--   Or see the source code [Picker:new at telescope.nvim/lua/telescope/pickers.lua](https://github.com/nvim-telescope/telescope.nvim/blob/7a4ffef931769c3fe7544214ed7ffde5852653f6/lua/telescope/pickers.lua#L45).
--
--   But these fields is not supported: `finder`, `attach_mappings`.
--   Because they are defined in telescope-extension-maker.
--
-- @prop [prompt_title=MakerExtension.name] {string}
-- @prop [results_title] {string}
-- @prop [preview_title='Preview'] {string}
-- @prop [finder] {function} like finders.new_table
-- @prop [sorter='generic'] {Sorter|string}
-- @prop [previewer=false] {previewer|string|false}
-- @prop [layout_strategy] {table}
-- @prop [layout_config] {table}
-- @prop [scroll_strategy] {string}
-- @prop [selection_strategy] {string} Values: follow, reset, row
-- @prop [cwd] {string}
-- @prop [default_text] {string}
-- @prop [default_selection_index] {number}
--   Change the index of the initial selection row. Support negative number.
-- @prop [wrap_results=true] {boolean}

-- @class MakerExtension {table}
-- @prop name {string}
-- @prop command {string|function:{string[]|Item[]|nil}}
--   If it's string, it must be vimscript codes. See :h nvim_exec
--   If it's function, it must return string[] or Item[] or nil.
--   It supports async function. The function accept a callback as parameter, whose signature is `function(err, results)`.
--   You can invoke `callback(err)` to pass an error for exception. Or invoke `callback(nil, results)` to pass results.
-- @prop [setup] {function} function(ext_config, config)  See telescope.register_extension({setup})
-- @prop [onSubmit] {function} function(Item):nil . Callback when user press <CR>
-- @prop [format] {table}
--   {separator: string, items: table[]}
--   See :h telescope.pickers.entry_display
-- @prop [highlights] {table}  {<hl_name> = {hl_opts...}}
--   Set highlights used for displayer . See :h nvim_set_hl
-- @prop [picker] {PickerOptions}
-- @prop [refreshKey='<C-r>'] {string|false} Keymap to refresh results. Set false to cancel the keymap.

-- Create a telescope extension.
-- @param ext {MakerExtension}
function M.create(ext)
	ext = vim.tbl_extend('keep', ext, { picker = {}, highlights = {}, refreshKey = '<C-r>' })

	local name = ext.name

	for hlName, hlProps in pairs(ext.highlights) do set_hl(0, hlName, hlProps) end

	local extension = telescope.register_extension({
		-- function(ext_config, config)
		setup = ext.setup,
		exports = {
			[name] = function(opts)
				async(function()
					extCallback(opts, ext)
				end)()
			end,
		},
	})

	return extension
end

-- Create a telescope extension, and auto register to telescope.
-- No need to create _extension file and call telescope.load_extension()
-- @param ext {MakerExtension}
function M.register(ext)
	local extension = M.create(ext)

	telescope.extensions[ext.name] = extension.exports
	-- if ext.setup then ext.setup(extensions._config[name] or {}, require('telescope.config').values) end
	-- extensions._health[name] = ext.health

	return extension
end

return M
