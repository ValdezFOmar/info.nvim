local M = {}

function M.check()
    vim.health.start 'System'

    local info_path = vim.fn.exepath 'info'
    if info_path == '' then
        vim.health.error(
            '`info` executable not found',
            'Check that `info` is installed and available in path'
        )
    else
        vim.health.ok(('Executable found: `%s`'):format(info_path))
    end

    local cmd = vim.system({ info_path, '--version' }, { text = true }):wait(10000)
    if cmd.code ~= 0 then
        vim.health.error('`info --version` exit with code: ' .. cmd.code)
    end

    local min_version = '7.0'
    local version = assert(vim.version.parse(cmd.stdout))

    if vim.version.ge(version, min_version) then
        vim.health.ok(('Supported version: %s'):format(version))
    else
        vim.health.error(
            ('Unsupported `info` version: %s'):format(version),
            ('Upgrade to version %s or later'):format(min_version)
        )
    end
end

return M
