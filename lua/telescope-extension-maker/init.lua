-- telescope extension tools
local telescope = require('telescope')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local sorters = require('telescope-extension-maker.sorters')
local previewers = require('telescope-extension-maker.previewers')
local entry_display = require('telescope.pickers.entry_display')

local M = {}

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
local entryMaker = function(item, displayer)
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

-- @param userOpts {table} user config of telescope extension
-- @param ext {MakerExtension}
local function extCallback(userOpts, ext)
	local items
	local getResults

	ext = vim.tbl_extend('keep', ext, { picker = {}, highlights = {}, refreshKey = '<C-r>' })

	local opts = vim.tbl_extend('keep', userOpts or {}, ext.picker)

	opts = vim.tbl_extend('keep', opts, {
		default_selection_index = 1,
		prompt_title = ext.name,
		preview_title = 'Preview',
		previewer = false,
		sorter = 'generic',
		wrap_results = true,
	})

	local displayer
	if ext.format then displayer = entry_display.create(ext.format) end

	local previewer = opts.previewer
	if type(previewer) == 'string' then opts.previewer = previewers.get(previewer) end

	local sorter = opts.sorter
	if type(sorter) == 'string' then opts.sorter = sorters.get(sorter) end

	local command = ext.command
	if type(command) == 'function' then
		getResults = function()
			items = {}

			local r = command() or {}

			if type(r[1]) == 'string' then
				for _, text in pairs(r) do --
					if #text == 0 then goto continue end
					items[#items + 1] = { text = text }
					::continue::
				end
			else
				for _, item in pairs(r) do
					if not displayer then if #item.text == 0 then goto continue end end
					items[#items + 1] = item
					::continue::
				end
			end

			return items
		end
	else
		getResults = function()
			items = {}
			local r = vim.api.nvim_exec(command, true)

			for _, text in pairs(vim.split(r, '\n')) do --
				if #text > 0 then items[#items + 1] = { text = text } end
			end

			return items
		end
	end

	local newFinder = function()
		return finders.new_table {
			results = getResults(),
			entry_maker = function(item)
				return entryMaker(item, displayer)
			end,
		}
	end

	opts.finder = newFinder()

	local selIdx = opts.default_selection_index
	if selIdx < 0 then opts.default_selection_index = #items + 1 + selIdx end

	opts.attach_mappings = function(prompt_bufnr, map)

		actions.select_default:replace(function()
			actions.close(prompt_bufnr)
			local selection = action_state.get_selected_entry()
			local item = items[selection.index]
			if ext.onSubmit then ext.onSubmit(item) end
		end)

		if ext.refreshKey then
			-- TODO: refactor after the PR merged. https://github.com/nvim-telescope/telescope.nvim/pull/2220
			local r = function()
				local picker = action_state.get_current_picker(prompt_bufnr)
				picker:refresh(newFinder(), { reset_prompt = false })
			end
			map('i', ext.refreshKey, r)
			map('n', ext.refreshKey, r)
		end

		return true
	end

	for hlName, hlProps in pairs(ext.highlights) do set_hl(0, hlName, hlProps) end

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
--   Or see the source code at telescope.nvim/lua/telescope/pickers.lua Picker:new
--
--   But these fields is not supported: finder, attach_mappings
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
-- @prop command {string|function}
--   If it's string, it must be vimscript codes. See :h nvim_exec
--   If it's function, it must return string[] or Item[]
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
	local name = ext.name

	local extension = telescope.register_extension({
		-- function(ext_config, config)
		setup = ext.setup,
		exports = {
			[name] = function(opts)
				extCallback(opts, ext)
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
