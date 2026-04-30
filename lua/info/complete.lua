local M = {}

---@type string[]?
local manual_entries

---@return string[]
local function get_manuals()
    if manual_entries then
        return manual_entries
    end
    manual_entries = {}
    local proc = vim.system({ 'info', '--output', '-' }, { text = true }):wait(10000)
    local doc = require('info.parser').parse(assert(proc.stdout))
    if doc then
        for _, entry in ipairs(doc.menu.entries) do
            table.insert(manual_entries, entry.target.file)
        end
        vim.list.unique(manual_entries)
        table.sort(manual_entries)
    end
    return manual_entries
end

---Complete manual names.
---
---@param arg_lead string
---@param cmd_line string
---@param cursor_pos integer
---@return string[]
function M.complete(arg_lead, cmd_line, cursor_pos)
    vim.validate('arg_lead', arg_lead, 'string')
    vim.validate('cmd_line', cmd_line, 'string')
    vim.validate('cursor_pos', cursor_pos, 'number')

    -- For simplicity, only complete at the end of the line
    if cursor_pos ~= #cmd_line then
        return {}
    end

    local fargs = vim.api.nvim_parse_cmd(cmd_line, {}).args

    if not fargs or #fargs == 0 then
        return get_manuals()
    elseif #fargs == 1 and arg_lead ~= '' then
        local manuals = {} ---@type string[]
        for _, name in ipairs(get_manuals()) do
            if vim.startswith(name, arg_lead) then
                manuals[#manuals + 1] = name
            end
        end
        return manuals
    else
        -- TODO: Support completing node names (#fargs == 2).
        -- The `dir` file only contains some nodes. To get all the nodes for a manual:
        -- info --output - --subnodes {manual} | rg '^\*\s+\S'
        return {}
    end
end

return M
