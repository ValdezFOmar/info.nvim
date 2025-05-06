local api = vim.api
local map = vim.keymap.set
local command = api.nvim_buf_create_user_command

vim.bo.expandtab = false
vim.bo.shiftwidth = 8
vim.bo.softtabstop = 8
vim.bo.tabstop = 8

local win = api.nvim_get_current_win()
vim.wo[win][0].spell = false
vim.wo[win][0].number = false
vim.wo[win][0].relativenumber = false
vim.wo[win][0].conceallevel = 2
vim.wo[win][0].concealcursor = 'nc'

local info = require '_info'

command(0, 'InfoNext', function(p)
    info.goto_node('Next', p.smods)
end, {})

command(0, 'InfoPrev', function(p)
    info.goto_node('Prev', p.smods)
end, {})

command(0, 'InfoUp', function(p)
    info.goto_node('Up', p.smods)
end, {})

command(0, 'InfoFollow', function(p)
    info.follow(p.smods)
end, {})

command(0, 'InfoMenu', function()
    info.menu()
end, { desc = 'Show menu entries' })

map('n', 'q', '<C-w>c', { desc = 'Close info window', buffer = true })
map('n', 'K', '<cmd>InfoFollow<CR>', { desc = 'Follow node reference under cursor', buffer = true })
map('n', 'gn', '<cmd>InfoNext<CR>', { desc = 'Go to the next node', buffer = true })
map('n', 'gp', '<cmd>InfoPrev<CR>', { desc = 'Go to the previous node', buffer = true })
map('n', 'gu', '<cmd>InfoUp<CR>', { desc = 'Go up one level', buffer = true })
