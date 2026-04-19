vim.bo.expandtab = false
vim.bo.shiftwidth = 8
vim.bo.softtabstop = 8
vim.bo.tabstop = 8

vim.wo[0][0].spell = false
vim.wo[0][0].number = false
vim.wo[0][0].relativenumber = false
vim.wo[0][0].conceallevel = 2
vim.wo[0][0].concealcursor = 'nc'
vim.wo[0][0].list = false

vim.api.nvim_buf_create_user_command(0, 'InfoMenu', function()
    require('info.buf').menu()
end, { desc = 'Show menu entries' })

vim.keymap.set('n', '<Plug>(info-follow)', function()
    require('info.buf').follow()
end, { buf = 0, desc = 'Follow node reference under cursor' })

vim.keymap.set('n', '<Plug>(info-next)', function()
    require('info.buf').goto_node 'Next'
end, { buf = 0, desc = 'Go to the next node' })

vim.keymap.set('n', '<Plug>(info-prev)', function()
    require('info.buf').goto_node 'Prev'
end, { buf = 0, desc = 'Go to the previous node' })

vim.keymap.set('n', '<Plug>(info-up)', function()
    require('info.buf').goto_node 'Up'
end, { buf = 0, desc = 'Go up one level' })

vim.keymap.set('n', 'K', '<Plug>(info-follow)', { buf = 0 })
vim.keymap.set('n', 'gn', '<Plug>(info-next)', { buf = 0 })
vim.keymap.set('n', 'gp', '<Plug>(info-prev)', { buf = 0 })
vim.keymap.set('n', 'gu', '<Plug>(info-up)', { buf = 0 })
vim.keymap.set('n', 'q', '<C-w>c', { buf = 0 })
