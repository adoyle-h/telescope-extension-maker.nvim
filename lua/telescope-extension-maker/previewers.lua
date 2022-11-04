local previewers = require('telescope.previewers')

local P = {}

P.cat = previewers.vim_buffer_cat
P.gitDiff = previewers.git_file_diff

-- @param name {string}
-- see https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/previewers/init.lua
-- @param [opts] {table}
function P.get(name, opts)
	local previewer = P[name] or previewers[name]
	return previewer.new(opts or {})
end

return P
