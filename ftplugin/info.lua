vim.bo.expandtab = false
vim.bo.shiftwidth = 8
vim.bo.softtabstop = 8
vim.bo.tabstop = 8

local win = vim.api.nvim_get_current_win()
vim.wo[win][0].spell = false
