local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local command = vim.api.nvim_create_user_command

command('Info', function(params)
    local err = require('info').open(params.fargs, params.smods)
    if err then
        vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
    end
end, { nargs = 1 })

autocmd('BufReadCmd', {
    group = augroup('info.nvim', {}),
    pattern = 'info://*',
    callback = function(ev)
        local err = require('info')._read(assert(ev.match:match 'info://(.+)'))
        if err then
            vim.notify('info.nvim: ' .. err, vim.log.levels.ERROR)
            return
        end

        -- TODO: set buffer local commands / keymaps
    end,
})
