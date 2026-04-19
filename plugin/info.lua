if vim.g.loaded_info ~= nil then
    return
end
vim.g.loaded_info = true

local hl = require 'info.hl'
hl.set_groups()

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local command = vim.api.nvim_create_user_command

local group = augroup('info.nvim', {})

-- TODO: Implement `:Info!` (with a bang) similar to `:help!` and assign to `keywordprg`
command('Info', function(params)
    local err = require('info.buf').open(params.fargs, params.smods)
    if err then
        vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
    end
end, { nargs = '*' })

autocmd('BufReadCmd', {
    group = group,
    pattern = 'info://*',
    callback = function(ev)
        local err = require('info.buf').read(ev.buf, assert(ev.match:match '^info://(.*)$'))
        if err then
            vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
            return
        end
    end,
})

autocmd('ColorScheme', {
    group = group,
    callback = function()
        hl.set_groups()
    end,
})
