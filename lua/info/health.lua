local M = {}
local MIN_INFO_VERSION = { 7, 0 }

function M.check()
    vim.health.start 'info.nvim'

    local info_path = vim.fn.exepath 'info'
    if info_path == '' then
        vim.health.error '`info` executable not found'
    else
        vim.health.ok('`info` executable found (' .. info_path .. ')')
    end

    local cmd = vim.system({ info_path, '--version' }, { text = true }):wait(10000)
    if cmd.code ~= 0 then
        vim.health.error('`info --version` exit with code: ' .. cmd.code)
        return
    end

    local version = vim.split(assert(cmd.stdout), '\n')[1]:match '(%d+%.%d+)'
    if vim.version.ge(version, MIN_INFO_VERSION) then
        vim.health.ok('supported version ' .. version)
    else
        vim.health.warn(
            'unsupported version ' .. version,
            'upgrade to ' .. table.concat(MIN_INFO_VERSION, '.') .. ' or later'
        )
    end
end

return M
