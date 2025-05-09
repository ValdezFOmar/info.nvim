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
---@param line integer?
---@return string
local function build_uri(manual, node, line)
    local encode = vim.uri_encode
    if not node or node == manual then
        node = 'Top'
    end
    local params = line and '?line=' .. line or ''
    -- Info nodes' name may contain slashes ('/'),
    -- but these are not percent encoded using the default 'rfc3986'.
    -- example: (groff)I/O
    return 'info://' .. encode(manual, 'rfc2396') .. '/' .. encode(node, 'rfc2396') .. params
end

---@param uri string
---@return string? error
---@return string manual
---@return string? node
---@return integer? line
local function parse_ref(uri)
    local decode = vim.uri_decode
    local route, params = unpack(split(uri, '?'))
    local line = params and params:match 'line=(%d+)' ---@type string?
    local manual, node = unpack(split(route, '/')) ---@type string, string?
    if manual == '' then
        return 'invalid info reference: info://' .. uri, manual, nil, nil
    end
    manual = decode(manual)
    node = (node ~= nil and node ~= '') and decode(node) or nil
    return nil, manual, node, tonumber(line)
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

---@param row integer 0-indexed
---@param col integer 0-indexed
---@param range info.TextRange
---@return boolean
local function in_range(row, col, range)
    if row >= range.start_row and row <= range.end_row then
        if range.start_row == range.end_row then
            return col >= range.start_col and col < range.end_col
        elseif row == range.start_row then
            return col >= range.start_col
        elseif row == range.end_row then
            return col < range.end_col
        else
            return true -- cursor is in the middle of the start and end line, so is always in range
        end
    end
    return false
end

---@param mods table
function M.follow(mods)
    local manual = vim.b._info_manual ---@type info.Manual
    local pos = api.nvim_win_get_cursor(0)
    local row, col = pos[1] - 1, pos[2]
    local line_text = api.nvim_buf_get_lines(0, row, row + 1, true)[1]

    local xref ---@type info.Manual.XRef?
    --- check if current line is a menu entry
    if vim.startswith(line_text, '* ') then
        for _, entry in ipairs(manual.menu_entries) do
            if in_range(row, col, entry.range) then
                xref = entry
                break
            end
        end
    end

    if not xref then
        for _, entry in ipairs(manual.xreferences) do
            if in_range(row, col, entry.range) then
                xref = entry
                break
            end
        end
    end

    if not xref then
        vim.notify('info.lua: no cross-reference under cursor', vim.log.levels.ERROR)
        return
    end
    local uri = build_uri(xref.file, xref.node, xref.line)
    open_uri(uri, mods)
end

---@param key 'Prev'|'Next'|'Up'
---@param mods table
function M.goto_node(key, mods)
    local manual = vim.b._info_manual ---@type info.Manual
    local node = manual.relations[key:lower()] ---@type info.Manual.Node?
    if not node then
        return vim.notify(
            "info.lua: no '" .. key .. "' pointer for this node",
            vim.log.levels.ERROR
        )
    end
    local uri = build_uri(node.file, node.node)
    open_uri(uri, mods)
end

---@class info.MenuItem
---@field lnum integer
---@field text string
---@field filename string

function M.menu()
    local manual = vim.b._info_manual ---@type info.Manual?
    if not manual or #manual.menu_entries == 0 then
        vim.notify('info.lua: No menu entries for this node', vim.log.levels.ERROR)
        return
    end
    local items = {} ---@type info.MenuItem[]
    for _, entry in ipairs(manual.menu_entries) do
        items[#items + 1] = {
            text = entry.label,
            lnum = entry.line or 1,
            filename = build_uri(entry.file, entry.node, entry.line),
        }
    end
    fn.setloclist(0, items, ' ')
    fn.setloclist(0, {}, 'a', { title = 'Menu' })
    vim.cmd.lopen()
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

---@param args [string?, string?]
---@param mods table<string, any>
---@return string? err
function M.open(args, mods)
    vim.validate('args', args, 'table')
    vim.validate('mods', mods, 'table')

    local uri ---@type string?
    if #args == 0 then
        uri = build_uri 'dir'
    elseif #args == 1 or #args == 2 then
        local cmd
        if #args == 1 then
            cmd = { 'info', '--location', args[1] }
        else
            cmd = { 'info', '--location', '--file', args[1], '--node', args[2] }
        end
        local res = vim.system(cmd, { timeout = TIMEOUT, text = true }):wait()
        if res.code ~= 0 then
            return ('command error `%s`: %s'):format(vim.inspect(cmd), res.stderr or '')
        end

        local path = trim(res.stdout or '')

        if path == '' then
            return ('no manual found for "%s"'):format(table.concat(args, ' '))
        elseif path == '*manpages*' then
            return ('manpage available for "%s"'):format(table.concat(args, ' '))
        end

        local name = assert(vim.fs.basename(path):match '^([^.]+)') ---@type string
        uri = build_uri(name, #args == 1 and args[1] or args[2])
    else
        return 'too many arguments (max: 2): ' .. vim.inspect(args)
    end
    open_uri(uri, mods)
end

---@param file string
---@param node string?
---@return string? text
local function get_file_text(file, node)
    -- NOTE: Sometimes `info` can't find a node using the `--node` flag,
    -- but it can without it. Try different fallbacks until one succeeds,
    -- or all fail.
    local commands ---@type string[][]
    if node then
        commands = {
            { 'info', '--output', '-', '--file', file, '--node', node },
            { 'info', '--output', '-', '--file', file, node },
            { 'info', '--output', '-', file, node },
        }
    else
        commands = { { 'info', '--ouput', '-', '--file', file } }
    end
    for _, cmd in ipairs(commands) do
        local res = vim.system(cmd, { timeout = TIMEOUT, text = true }):wait()
        if res.code == 0 and res.stdout and res.stdout ~= '' then
            return res.stdout
        end
    end
end

---@param buf integer
---@param ref string
---@return string? err
function M.read(buf, ref)
    vim.validate('buf', buf, 'number')
    vim.validate('ref', ref, 'string')

    local err, file, node, line_offset = parse_ref(ref)
    if err then
        return err
    end

    local text = get_file_text(file, node)
    if not text then
        return 'no manual found for ' .. ref
    end
    local lines = split(text, '\n')

    --- Extra line created by `vim.split` because `info` outputs `\n\n` at the end
    if lines[#lines] == '' then
        lines[#lines] = nil
    end

    vim.bo.modifiable = true
    vim.bo.readonly = false
    vim.bo.swapfile = false
    api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    -- don't allow further changes in case parsing fails
    vim.bo.modifiable = false
    vim.bo.readonly = true

    if line_offset then
        local winid = fn.bufwinid(buf)
        local row = math.min(line_offset, api.nvim_buf_line_count(buf))
        vim.schedule(function()
            api.nvim_win_set_cursor(winid, { row, 0 })
        end)
    end

    local parser = require '_info.parser'
    local document = parser.parse(text)
    if not document then
        return 'fail parsing ' .. ref
    end

    local data = parser.as_buffer_data(document)
    vim.b[buf]._info_manual = data

    -- The file or node name supplied by the user may differ from the actual
    -- names in the manual because of how `info` searches for nodes.
    if file ~= data.file or node ~= data.node then
        api.nvim_buf_set_name(buf, build_uri(data.file, data.node, line_offset))
    end

    require('_info.hl').decorate_buffer(buf, document)
    set_options()
end

return M
