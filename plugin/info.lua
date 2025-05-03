if vim.g.loaded_info ~= nil then
    return
end
vim.g.loaded_info = true

local colors = require '_info.colors'
colors.set_groups()

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local command = vim.api.nvim_create_user_command

local group = augroup('info.nvim', {})

command('Info', function(params)
    local err = require('_info').open(params.fargs, params.smods)
    if err then
        vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
    end
end, { nargs = '*' })

autocmd('BufReadCmd', {
    group = group,
    pattern = 'info://*',
    callback = function(ev)
        local err = require('_info').read(ev.buf, assert(ev.match:match '^info://(.*)$'))
        if err then
            vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
            return
        end
    end,
})

autocmd('ColorScheme', {
    group = group,
    callback = function()
        colors.set_groups()
    end,
})
