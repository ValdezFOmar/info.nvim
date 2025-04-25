local fn = vim.fn
local api = vim.api
local trim = vim.trim
local split = vim.split

local TIMEOUT = 10000

local M = {}

---@param manual string
---@param node string?
---@return string
local function to_info_uri(manual, node)
    local encode = vim.uri_encode
    if not node or node == manual then
        node = 'Top'
    end
    return 'info://' .. encode(manual) .. '#' .. encode(node)
end

---@param uri string
---@return string manual
---@return string? node
local function parse_info_ref(uri)
    local decode = vim.uri_decode
    local parts = split(uri, '#')
    local manual = decode(parts[1])
    ---@type string?
    local node = parts[2]
    node = (node ~= nil and node ~= '') and decode(node) or nil
    return manual, node
end

--- Implementation taken from $VIMRUNTIME/lua/man.lua
---@return boolean
local function find_info_window()
    if vim.bo.filetype == 'info' then
        return true
    end

    local win = 1
    while win <= fn.winnr '$' do
        local buf = fn.winbufnr(win)
        if vim.bo[buf].filetype == 'info' then
            vim.cmd(win .. 'wincmd w')
            return true
        end
        win = win + 1
    end
    return false
end

local function set_options()
    vim.bo.bufhidden = 'unload'
    vim.bo.buftype = 'nofile'
    vim.bo.filetype = 'info'
    vim.bo.modifiable = false
    vim.bo.modified = false
    vim.bo.readonly = true
    vim.bo.swapfile = false
end

---@param args string[]
---@param mods table<string, any>
---@return string? err
function M.open(args, mods)
    local topic = args[1]
    --- maybe `--debug=3` could be useful?
    local cmd = { 'info', '--location', topic }
    local res = vim.system(cmd, { timeout = TIMEOUT, text = true }):wait()
    if res.code ~= 0 then
        return ('command error `%s`: %s'):format(table.concat(cmd, ' '), res.stderr or '')
    end

    local path = trim(res.stdout or '')

    if path == '' then
        return ('no manual found for "%s"'):format(topic)
    elseif path == '*manpages*' then
        return ('manpage available for "%s"'):format(topic)
    end

    ---@type string
    local name = assert(vim.fs.basename(path):match '^([^.]+)%.info%.gz$')
    local uri = to_info_uri(name, topic)
    local exargs = { fn.fnameescape(uri), mods = mods }

    mods.silent = true
    if mods.hide or mods.tab == -1 and find_info_window() then
        vim.cmd.edit(exargs)
    else
        vim.cmd.split(exargs)
    end
end

---@param buf integer
---@param ref string
---@return string? err
function M._read(buf, ref)
    vim.validate('buf', buf, 'number')
    vim.validate('ref', ref, 'string')

    local manual, node = parse_info_ref(ref)
    if manual == '' then
        return ('not a valid manual "%s"'):format(ref)
    end

    local cmd = { 'info', '--output', '-', '--file', manual }
    if node then
        table.insert(cmd, '--node')
        table.insert(cmd, node)
    end

    local res = vim.system(cmd, { timeout = TIMEOUT, text = true }):wait()
    if res.code ~= 0 then
        local message = res.stderr and res.stderr:match ':%s*([^:]+)$' or ''
        return ('no manual found for "%s": %s'):format(ref, trim(message))
    end
    local text = assert(res.stdout)
    local lines = split(text, '\n')

    --- Extra line created by `vim.split` because `info` outputs `\n\n` at the end
    if lines[#lines] == '' then
        lines[#lines] = nil
    end

    vim.bo.modifiable = true
    vim.bo.readonly = false
    vim.bo.swapfile = false
    api.nvim_buf_set_lines(0, 0, -1, false, lines)

    local info_manual = require('_info.parser').parse(text)
    if not info_manual then
        return 'fail parsing ' .. ref
    end

    vim.b[buf]._info_manual = info_manual

    set_options()
end

return M
