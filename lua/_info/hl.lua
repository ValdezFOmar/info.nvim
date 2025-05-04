local M = {}

local api = vim.api
local ns = api.nvim_create_namespace 'info.nvim'

---@enum info.hl.Group
local groups = {
    URI = 'InfoUri',
    File = 'InfoFile',
    Node = 'InfoNode',
    Heading = 'InfoHeading',
    Heading1 = 'InfoHeading1',
    Heading2 = 'InfoHeading2',
    Heading3 = 'InfoHeading3',
    Heading4 = 'InfoHeading4',
    ListMarker = 'InfoListMarker',
    ReferenceLabel = 'InfoReferenceLabel',
    ReferenceTarget = 'InfoReferenceTarget',
}
M.groups = groups

---@type table<info.hl.Group, string>
local colors = {
    [groups.URI] = '@markup.link.url',
    [groups.File] = '@string.special.path',
    [groups.Node] = '@markup.link',
    [groups.Heading] = '@markup.heading',
    [groups.Heading1] = '@markup.heading.1',
    [groups.Heading2] = '@markup.heading.2',
    [groups.Heading3] = '@markup.heading.3',
    [groups.Heading4] = '@markup.heading.4',
    [groups.ListMarker] = '@markup.list',
    [groups.ReferenceLabel] = '@markup.link.label',
    [groups.ReferenceTarget] = '@markup.link',
}

function M.set_groups()
    for name, link in pairs(colors) do
        api.nvim_set_hl(0, name, { link = link, default = true })
    end
end

---@param bufnr integer
---@param group info.hl.Group
---@param range info.TextRange
local function hl_range(bufnr, group, range)
    api.nvim_buf_set_extmark(bufnr, ns, range.start_row, range.start_col, {
        end_row = range.end_row,
        end_col = range.end_col,
        hl_group = group,
    })
end

---Style common cross-reference elements (i.e. inline references and menu entries).
---@param bufnr integer
---@param ref info.doc.Reference
local function style_reference(bufnr, ref)
    hl_range(bufnr, groups.ReferenceLabel, ref.label.range)
    if ref.target.range then
        hl_range(bufnr, groups.ReferenceTarget, ref.target.range)
    else
        ---Conceal `::` for shorthand references.
        local start_row = ref.range.end_row
        local start_col = ref.label.range.end_col
        api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col, {
            end_row = start_row,
            end_col = start_col + 2,
            conceal = '',
        })
    end
end

---@param bufnr integer
---@param doc info.doc.Document
function M.decorate_buffer(bufnr, doc)
    local ElementType = require('_info.parser').ElementType

    local file = doc.header.meta.file
    local node = doc.header.meta.node
    hl_range(bufnr, groups.Heading, file.range)
    hl_range(bufnr, groups.Heading, node.range)
    hl_range(bufnr, groups.File, file.target.range)
    hl_range(bufnr, groups.Node, node.target.range)

    for _, rel in pairs(doc.header.relations) do
        ---@cast rel info.doc.Header.Relation
        hl_range(bufnr, groups.Heading, rel.range)
        hl_range(bufnr, groups.Node, rel.target.range)
    end

    if doc.header.desc then
        hl_range(bufnr, groups.Heading, doc.header.desc)
    end

    -- Conceal `File:` and `Node:` keys, mimicking `info`
    do
        local h = doc.header
        local r = doc.header.relations
        local end_col = math.min(
            h.desc and h.desc.start_col or math.huge,
            r.next and r.next.range.start_col or math.huge,
            r.prev and r.prev.range.start_col or math.huge,
            r.up and r.up.range.start_col or math.huge
        )
        if end_col ~= math.huge then
            api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
                end_row = 0,
                end_col = end_col,
                conceal = '',
            })
        end
    end

    for _, heading in ipairs(doc.headings) do
        local group = groups['Heading' .. heading.level] ---@type info.hl.Group?
        if group then
            hl_range(bufnr, group, heading.range)
            api.nvim_buf_set_extmark(bufnr, ns, heading.range.end_row, 0, {
                virt_text_pos = 'overlay',
                virt_text_hide = true,
                virt_text = { { heading.char:rep(80), group } }, -- Info pages are justified to 80 characters or less
            })
        end
    end
    if doc.menu.header then
        hl_range(bufnr, groups.Heading, doc.menu.header.range)
    end
    for _, entry in ipairs(doc.menu.entries) do
        local row = entry.range.start_row
        local col = entry.range.start_col
        api.nvim_buf_set_extmark(bufnr, ns, row, col, {
            end_row = row,
            end_col = col + 1,
            hl_group = groups.ListMarker,
        })
        style_reference(bufnr, entry)
    end
    for _, ref in ipairs(doc.references) do
        -- Conceal '*Note' annotations.
        -- If the label starts at the same row as '*Note' starts,
        -- then there is an extra single space ' ' that should be counted
        -- Example: '*Note Definitions::'
        local col_offset = ref.range.start_row == ref.label.range.start_row and 6 or 5
        api.nvim_buf_set_extmark(bufnr, ns, ref.range.start_row, ref.range.start_col, {
            end_row = ref.range.start_row,
            end_col = ref.range.start_col + col_offset,
            conceal = '',
        })
        style_reference(bufnr, ref)
    end
    if doc.footnotes then
        hl_range(bufnr, groups.Heading, doc.footnotes.heading.range)
    end
    for _, element in ipairs(doc.misc) do
        if element.type == ElementType.InlineURI then
            hl_range(bufnr, groups.URI, element.range)
        end
    end
end

return M
