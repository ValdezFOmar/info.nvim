if vim.g.loaded_info ~= nil then
    return
end
vim.g.loaded_info = true

local api = vim.api
local group = api.nvim_create_augroup('info.nvim', {})

api.nvim_create_user_command('Info', function(params)
    local info = require 'info.buf'
    local mods = params.smods
    local args = params.fargs

    local err ---@type string?
    if params.bang then
        err = info.open_cursor(mods)
    elseif #args == 0 then
        err = info.open({ file = 'dir', item = 'Top' }, mods)
    elseif #args == 1 then
        err = info.open({ item = args[1] }, mods)
    elseif #args == 2 then
        err = info.open({ file = args[1], item = args[2] }, mods)
    else
        err = 'too many arguments (max: 2): ' .. vim.inspect(args)
    end
    if err then
        vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
    end
end, {
    bang = true,
    nargs = '*',
    complete = function(...)
        return require('info.complete').complete(...)
    end,
})

api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    pattern = 'info://*',
    callback = function(ev)
        local err = require('info.buf').read(ev.buf, assert(ev.match:match '^info://(.*)$'))
        if err then
            vim.schedule(function()
                vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
            end)
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
