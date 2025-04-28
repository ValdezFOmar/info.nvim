local M = {}

---@enum info.Element
local ElementType = {
    MenuEntry = 'MenuEntry',
    XReference = 'XReference',
}

local lpeg = vim.lpeg
local S = lpeg.S
local P = lpeg.P
local B = lpeg.B
local Cp = lpeg.Cp
local Ct = lpeg.Ct
local Cg = lpeg.Cg

local START = Cg(Cp(), 'start')
local END = Cg(Cp(), 'end_')

---@param pattern vim.lpeg.Pattern
---@param name string?
---@return vim.lpeg.Pattern
local function Cpos(pattern, name)
    return START * Cg(pattern, name or 'text') * END
end

---@param name string
---@param pattern vim.lpeg.Pattern
---@return vim.lpeg.Pattern
local function Cgt(name, pattern)
    return Cg(Ct(pattern), name)
end

---@param pattern any
local function opt(pattern)
    return P(pattern) ^ -1
end

---@param element info.Element
---@return vim.lpeg.Pattern
local function Ctype(element)
    return Cg(lpeg.Cc(element), 'type')
end

--- Info manual PEG parser
local manual_pattern = (function()
    local SP = S ' \t' ^ 1 --- spaces
    local MSP = S ' \t\n' ^ 1 --- multi line spaces
    local SWALLOW_LINE = (P(1) - '\n') ^ 0 * '\n'

    ---@param key string
    ---@return vim.lpeg.Pattern
    local function header_key(key)
        local text = (P(1) - S ',\n\t') ^ 1
        return START * Cgt('value', key * SP * Cpos(text)) * END
    end

    local COMMA = ',' * SP
    local file_name = header_key 'File:'
    local this_node = header_key 'Node:'
    local next_node = header_key 'Next:'
    local prev_node = header_key 'Prev:'
    local up_node = header_key 'Up:'
    local node_header = Cgt('file', file_name)
        * COMMA
        * Cgt('node', this_node)
        * opt(COMMA * Cgt('next', next_node))
        * opt(COMMA * Cgt('prev', prev_node))
        * opt(COMMA * Cgt('up', up_node))
        * SWALLOW_LINE -- Extra text (see `info --file dir`)

    local reference_text = (P(1) - ':') ^ 1
    local reference_node = (P(1) - S '.,\t\n') ^ 1
    local reference = Cgt('label', Cpos(reference_text))
        * ':'
        * (':' + SP * Cgt('target', Cpos(reference_node)))

    local menu_entry = Ctype(ElementType.MenuEntry)
        * B '\n' -- menu entries only appear at the start of lines
        * START
        * '* '
        * -#P 'Menu:' -- this is not an entry, but the header for the input
        * reference
        * END
        * SWALLOW_LINE -- entry description / comment

    local inline_reference = Ctype(ElementType.XReference)
        * START
        * '*'
        * S 'Nn'
        * 'ote'
        * MSP -- reference can continue the next line
        * reference
        * END

    local line = Ct(menu_entry) + Ct(inline_reference) + 1

    return Ct(Cgt('header', node_header) * Cgt('elements', line ^ 0) * -1)
end)()

local lines_pattern = Ct(
    Ct(START * (P(1) - '\n') ^ 0 * END * '\n') ^ 0 * -1 * Ct(START * END) -- additional empty line for simplifying line/column calculations
)

---@param text string
---@return string
local function fold_spaces(text)
    text = text:gsub('%s+', ' ')
    return text
end

---@param ref string
---@return string? file
---@return string? node
local function parse_reference(ref)
    ---@type string?, integer?
    local file, len = ref:match '^%(([^)]+)()%)'
    local node ---@type string?
    if not len then
        node = ref
    elseif #ref > len then
        node = ref:sub(len + 1)
    end
    assert(file or node, 'at least one of `file` or `node` should be defined')
    return file, node
end

---@param rel info.parser.Header.Pair
---@param this_file string
---@return info.Manual.Node
local function build_relation(rel, this_file)
    local file, node = parse_reference(rel.value.text)
    return {
        start = { line = 1, col = rel.start - 1 },
        end_ = { line = 1, col = rel.end_ - 2 }, -- Extra `-1` to make end-inclusive
        target = {
            file = file or this_file,
            node = node or 'Top',
        },
    }
end

---@class info.build_xref.Positions
---@field start_index integer
---@field start_line integer
---@field end_index integer
---@field end_line integer

---@param ref info.parser.Reference
---@param this_file string
---@param pos info.build_xref.Positions
---@return info.Manual.XRef
local function build_xref(ref, this_file, pos)
    local label = fold_spaces(ref.label.text)
    local file, node ---@type string?, string?
    if ref.target then
        file, node = parse_reference(fold_spaces(ref.target.text))
    else
        file, node = this_file, label
    end
    ---@type info.Manual.XRef
    return {
        start = {
            col = ref.start - pos.start_index,
            line = pos.start_line,
        },
        end_ = {
            col = ref.end_ - pos.end_index - 1, -- Extra `-1` to make end-inclusive
            line = pos.end_line,
        },
        label = label,
        target = {
            file = file or this_file,
            node = node or 'Top',
        },
    }
end

---Parse and info document node.
---@param text string
---@return info.Manual?
function M.parse(text)
    ---@type info.parser.Captures?
    local caps = manual_pattern:match(text)
    if not caps then
        return
    end

    local file = caps.header.file.value.text
    local xreferences = {} ---@type info.Manual.XRef[]
    local menu_entries = {} ---@type info.Manual.XRef[]

    local lines = vim.iter(ipairs(lines_pattern:match(text)))

    local line ---@type integer
    local pos ---@type info.parser.Position
    local next_line ---@type integer
    local next_pos ---@type info.parser.Position

    line, pos = lines:next() --[[@as ...]]
    next_line, next_pos = lines:next() --[[@as ...]]

    for _, element in ipairs(caps.elements) do
        while not (element.start >= pos.start and element.start <= pos.end_) do
            line, pos = next_line, next_pos
            next_line, next_pos = lines:next() --[[@as ...]]
            assert(next_line and next_pos, "there's always an extra line") --- see `lines_pattern`
        end

        local xref = build_xref(element, file, {
            start_line = line,
            start_index = pos.start,
            end_line = element.end_ <= pos.end_ and line or next_line,
            end_index = element.end_ <= pos.end_ and pos.start or next_pos.start,
        })
        if element.type == ElementType.MenuEntry then
            table.insert(menu_entries, xref)
        elseif element.type == ElementType.XReference then
            table.insert(xreferences, xref)
        end
    end

    local node = caps.header.node.value.text
    local next = caps.header.next
    local prev = caps.header.prev
    local up = caps.header.up

    ---@type info.Manual
    return {
        file = file,
        node = node,
        relations = {
            next = next and build_relation(next, file),
            prev = prev and build_relation(prev, file),
            up = up and build_relation(up, file),
        },
        xreferences = xreferences,
        menu_entries = menu_entries,
    }
end

return M
