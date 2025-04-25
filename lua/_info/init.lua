local fn = vim.fn
local api = vim.api
local trim = vim.trim
local split = vim.split

local TIMEOUT = 10000

local M = {}

---Implementation taken from $VIMRUNTIME/lua/man.lua
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

---@param manual string
---@param node string?
---@return string
local function build_uri(manual, node)
    local encode = vim.uri_encode
    if not node or node == manual then
        node = 'Top'
    end
    return 'info://' .. encode(manual) .. '#' .. encode(node)
end

---@param uri string
---@param mods table
local function open_uri(uri, mods)
    mods = mods or {}
    mods.silent = true
    local exargs = { fn.fnameescape(uri), mods = mods }

    if mods.hide or mods.tab == -1 and find_info_window() then
        vim.cmd.edit(exargs)
    else
        vim.cmd.split(exargs)
    end
end

---@param line integer
---@param col integer
---@param range info.TextRange
---@return boolean
local function in_range(line, col, range)
    local start = range.start
    local end_ = range.end_

    if line >= start.line and line <= end_.line then
        if start.line == end_.line then
            return col >= start.col and col <= end_.col
        elseif line == start.line then
            return col >= start.col
        elseif line == end_.line then
            return col <= end_.col
        else
            return true -- cursor is in the middle of the start and end line, so is always in range
        end
    end

    return false
end

---@param mods table
function M.follow(mods)
    local manual = vim.b._info_manual ---@type info.Document
    local pos = api.nvim_win_get_cursor(0)
    local line, col = pos[1], pos[2]
    local line_text = api.nvim_buf_get_lines(0, line - 1, line, false)[1]

    local uri ---@type string?
    --- check if current line is a menu entry
    if vim.startswith(line_text, '* ') then
        for _, entry in ipairs(manual.menu_entries) do
            if in_range(line, col, entry) then
                uri = build_uri(entry.target.file, entry.target.node)
                break
            end
        end
    end

    if not uri then
        for _, entry in ipairs(manual.xreferences) do
            if in_range(line, col, entry) then
                uri = build_uri(entry.target.file, entry.target.node)
                break
            end
        end
    end

    if not uri then
        vim.notify('info.lua: no cross-reference under cursor', vim.log.levels.ERROR)
        return
    end
    open_uri(uri, mods)
end

---@param key 'Prev'|'Next'|'Up'
---@param mods table
function M.goto_node(key, mods)
    local manual = vim.b._info_manual ---@type info.Document
    local node = manual.relations[key:lower()] ---@type info.Document.Relation?
    if not node then
        return vim.notify(
            "info.lua: no '" .. key .. "' pointer for this node",
            vim.log.levels.ERROR
        )
    end
    local uri = build_uri(node.target.file, node.target.node)
    open_uri(uri, mods)
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
    local uri = build_uri(name, topic)
    open_uri(uri, mods)
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
