if vim.g.loaded_info ~= nil then
    return
end
vim.g.loaded_info = true

local api = vim.api
local group = api.nvim_create_augroup('info.nvim', {})

api.nvim_create_user_command('Info', function(params)
    local info = require 'info.buf'
    local err ---@type string?
    if params.bang then
        err = info.open_reference(params.smods)
    else
        err = info.open(params.fargs, params.smods)
    end
    if err then
        vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
    end
end, { nargs = '*', bang = true })

api.nvim_create_autocmd('BufReadCmd', {
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

local hl = require 'info.hl'
hl.set_groups()

api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
        hl.set_groups()
    end,
})
