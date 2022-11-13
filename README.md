# telescope-extension-maker.nvim

Easy to make a telescope extension. It supports [async function](#async-command).

## Dependencies

- [telescope](https://github.com/nvim-telescope/telescope.nvim)

## Installation

### Using vim-plug

```lua
Plug 'nvim-telescope/telescope.nvim'
Plug 'adoyle-h/telescope-extension-maker.nvim'
```

### Using packer.nvim

```lua
use { 'nvim-telescope/telescope.nvim' }
use { 'adoyle-h/telescope-extension-maker.nvim' }
```

### Using dein

```lua
call dein#add('nvim-telescope/telescope.nvim')
call dein#add('adoyle-h/telescope-extension-maker.nvim')
```

## Examples

More examples see [ad-telescope-extensions](https://github.com/adoyle-h/ad-telescope-extensions.nvim) and [here](https://github.com/adoyle-h/one.nvim/blob/master/lua/one/plugins/telescope/extensions.lua).

### The simplest

```lua
require('telescope').setup()
local maker = require('telescope-extension-maker')

maker.register {
  name = 'rtp',
  command = 'set rtp', -- vimscript
}
```

`:Telescope rtp`

### Picker Options

```lua
maker.register {
  name = 'message',
  command = 'messages',
  picker = {
    sorting_strategy = 'ascending',
    default_selection_index = -1,
  }
}
```

See [Types - PickerOptions](#picker-options).

### Command function

```lua
maker.register {
  name= 'colors',
  command = function()
    local items = {}

    for key, value in pairs(vim.api.nvim_get_color_map()) do
      table.insert(items, {
        text = string.format('%s = %s', key, value),
        entry = { ordinal = key .. '=' .. value },
      })
    end

    return items
  end,
}
```

### Preview file

```lua
maker.register {
  name = 'scriptnames',
  picker = { previewer = 'cat' },
  command = function()
    local output = vim.api.nvim_exec('scriptnames', true)
    return vim.tbl_map(function(text)
      local _, _, path = string.find(text, '^%s*%d+: (.+)')
      return { text = text, entry = { path = path } }
    end, vim.split(output, '\n'))
  end,
}
```

### Highlight text

```lua
maker.register {
  name = 'env',

  highlights = {
    tel_ext_envs_1 = { fg = '#C3B11A' },
    tel_ext_envs_2 = { fg = '#34373B' },
  },

  -- See :h telescope.pickers.entry_display
  format = {
    separator = ' ',
    items = { {}, {}, {} },
  },

  command = function()
    local items = {}

    for key, value in pairs(vim.fn.environ()) do
      table.insert(items, {
        -- When displayer set, text must be a table.
        -- See :h telescope.pickers.entry_display
        text = { { key, 'tel_ext_envs_1' }, { '=', 'tel_ext_envs_2' }, value },

        entry = {
          ordinal = key .. '=' .. value,
        },
        key = key,
        value = value,
      })
    end

    return items
  end,
}
```

### onSubmit

```lua
maker.register {
  name = 'changes',

  command = function()
    local items = {}
    for change in vim.api.nvim_exec('changes', true):gmatch('[^\r\n]+') do
      items[#items + 1] = change
    end
    return items
  end,

  onSubmit = function(item)
    local _, _, str = string.find(item.text, '^%s+%d+%s+(%d+)')
    vim.api.nvim_win_set_cursor(0, { tonumber(str), 0 })
  end,
}
```

### Async Command

It supports async function. The function accept a callback as parameter, whose signature is `function(err, results)`.

You can invoke `callback(nil, results)` to pass results.

```lua
maker.register {
  name = 'hello',
  command = function(callback)
    vim.defer_fn(function()
      local items = { 'a', 'b', 'c' }
      callback(nil, items)
    end, 3000)
  end,
}
```

```lua
maker.register {
  name = 'hello2',
  command = function(callback)
    local items = { 'a', 'b', 'c' }
    callback(nil, items)
  end,
}
```

You can invoke `callback(err)` to pass an error for exception.

```lua
maker.register {
  name = 'hello3',
  command = function(callback)
    callback(error('failed'))
  end,
}
```

## API

### register(ext)

```lua
-- Create a telescope extension, and auto register to telescope.
-- No need to create _extension file and call telescope.load_extension()
-- @param ext {MakerExtension}
function register(ext)
```

### create(ext)

```lua
-- Create a telescope extension.
-- @param ext {MakerExtension}
function create(ext)
```

Examples, create a file `lua/telescope/_extensions/message` and its content is:

```lua
return require('telescope-extension-maker').create {
  name = 'message',
  command = 'messages',
  picker = {
    sorting_strategy = 'ascending',
    default_selection_index = -1,
  }
}
```

## Types

### MakerExtension

```lua
-- @class MakerExtension {table}
-- @prop name {string}
-- @prop command {string|function}
--   If it's string, it must be vimscript codes. See :h nvim_exec
--   If it's function, it must return string[] or Item[]
-- @prop command {string|function:{string[]|Item[]|nil}}
--   If it's string, it must be vimscript codes. See :h nvim_exec
--   If it's function, it must return string[] or Item[] or nil.
--   The function accept a callback for async command. Its signature is function(err, results).
--   You can invoke callback(err) to pass an error in command. Or invoke callback(nil, results) to pass results.
-- @prop [setup] {function} function(ext_config, config)  See telescope.register_extension({setup})
-- @prop [onSubmit] {function} function(Item):nil . Callback when user press <CR>
-- @prop [format] {table}
--   {separator: string, items: table[]}
--   See :h telescope.pickers.entry_display
-- @prop [highlights] {table}  {<hl_name> = {hl_opts...}}
--   Set highlights used for displayer . See :h nvim_set_hl
-- @prop [picker] {PickerOptions}
-- @prop [refreshKey='<C-r>'] {string|false} Keymap to refresh results. Set false to cancel the keymap.
```

### Item

```lua
-- @class Item {table}
-- @prop text {string|table}
-- @prop [entry] {EntryOpts}
-- @prop [<any-key> = <any-value>] -- You can set any key/value pairs into item
```

### PickerOptions

```lua
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
```

### EntryOpts

```lua
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
```

## Suggestion, Bug Reporting, Contributing

Any suggestions and contributions are always welcome. Please open an [issue][] to contact with me.

If you want to submit a new feature, please open an [issue][] for feature request to talk about your design.

If you want to submit a bug fix, search related issues first, and then open a Pull Requst.

## Versions

See [tags][].
The versions follows the rules of [SemVer 2.0.0](http://semver.org/).

## Copyright and License

Copyright 2022 ADoyle (adoyle.h@gmail.com) Some Rights Reserved.
The project is licensed under the **Apache License Version 2.0**.

See the [LICENSE][] file for the specific language governing permissions and limitations under the License.

See the [NOTICE][] file distributed with this work for additional information regarding copyright ownership.

## Other Projects

[Other lua projects](https://github.com/adoyle-h?tab=repositories&q=&type=source&language=lua&sort=stargazers) created by me.


<!-- Links -->

[LICENSE]: ./LICENSE
[NOTICE]: ./NOTICE
[tags]: https://github.com/adoyle-h/telescope-extension-maker.nvim/tags
[issue]: https://github.com/adoyle-h/telescope-extension-maker.nvim/issues
