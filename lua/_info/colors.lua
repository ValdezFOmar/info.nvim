local M = {}
local api = vim.api

---@enum info.colors.Group
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

---@type table<info.colors.Group, string>
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

return M
