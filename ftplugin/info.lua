vim.bo.tabstop = 8
vim.bo.keywordprg = ':Info!'

vim.wo[0][0].spell = false
vim.wo[0][0].number = false
vim.wo[0][0].relativenumber = false
vim.wo[0][0].conceallevel = 2
vim.wo[0][0].concealcursor = 'nc'
vim.wo[0][0].list = false

vim.keymap.set('n', '<Plug>(info-toc)', function()
    require('info.buf').toc()
end, { buf = 0, desc = 'Show the table of contents' })

vim.keymap.set('n', '<Plug>(info-next-node)', function()
    require('info.buf').goto_node 'Next'
end, { buf = 0, desc = 'Go to the next node' })

vim.keymap.set('n', '<Plug>(info-prev-node)', function()
    require('info.buf').goto_node 'Prev'
end, { buf = 0, desc = 'Go to the previous node' })

vim.keymap.set('n', '<Plug>(info-up-node)', function()
    require('info.buf').goto_node 'Up'
end, { buf = 0, desc = 'Go up one node' })

vim.keymap.set('n', 'gO', '<Plug>(info-toc)', { buf = 0, desc = 'Show the table of contents' })
vim.keymap.set('n', 'gn', '<Plug>(info-next-node)', { buf = 0, desc = 'Go to the next node' })
vim.keymap.set('n', 'gp', '<Plug>(info-prev-node)', { buf = 0, desc = 'Go to the previous node' })
vim.keymap.set('n', 'gu', '<Plug>(info-up-node)', { buf = 0, desc = 'Go up one node' })
vim.keymap.set('n', 'q', '<C-w>c', { buf = 0, desc = 'Close window' })
