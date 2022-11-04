local sorters = require('telescope.sorters')

local S = {}

S.empty = sorters.empty
S.file = sorters.get_fuzzy_file
S.generic = sorters.get_generic_fuzzy_sorter
S.index_bias = sorters.fuzzy_with_index_bias
S.fzy = sorters.get_fzy_sorter
S.highlight = sorters.highlighter_only
S.levenshtein = sorters.get_levenshtein_sorter
S.substr = sorters.get_substr_matcher
S.prefilter = sorters.prefilter

-- @param name {string}
-- See https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/sorters.lua
-- @param [opts] {table}
function S.get(name, opts)
	local sorter = S[name] or sorters[name]
	return sorter(opts or {})
end

return S
