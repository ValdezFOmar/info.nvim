local map = vim.tbl_map

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
        * - #P 'Menu:' -- this is not an entry, but the header for the input
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

---@class info.parser.Offset
---@field start_offset integer
---@field start_line integer
---@field end_offset integer
---@field end_line integer

---@param pos info.parser.Position
---@param offset info.parser.Offset
---@return info.TextRange
local function calc_range(pos, offset)
    ---@type info.TextRange
    return {
        start_row = offset.start_line,
        start_col = pos.start - offset.start_offset,
        end_row = offset.end_line,
        end_col = pos.end_ - offset.end_offset - 1, -- Extra `-1` to make end-inclusive
    }
end

---@param rel info.parser.Header.Pair
---@param this_file string
---@param offset info.parser.Offset
---@return info.doc.Header.Relation
local function build_relation(rel, this_file, offset)
    local file, node = parse_reference(rel.value.text)
    ---@type info.doc.Header.Relation
    return {
        range = calc_range(rel, offset),
        target = {
            range = calc_range(rel.value, offset),
            file = file or this_file,
            node = node or 'Top',
        },
    }
end

---@param ref info.parser.Reference
---@param this_file string
---@param offset info.parser.Offset
---@return info.doc.Reference
local function build_xref(ref, this_file, offset)
    local label = fold_spaces(ref.label.text)
    local file, node ---@type string?, string?
    if ref.target then
        file, node = parse_reference(fold_spaces(ref.target.text))
    else
        file, node = this_file, label
    end
    -- TODO: maybe calculate the range for `label` and `target`
    ---@type info.doc.Reference
    return {
        range = calc_range(ref, offset),
        label = { text = label },
        target = {
            file = file or this_file,
            node = node or 'Top',
        },
    }
end

---@class info.iter_lines.Line
---@field row integer
---@field start integer
---@field end_ integer

---@param text string
---@return fun(): info.iter_lines.Line, info.iter_lines.Line
local function iter_lines(text)
    local line_ends = text:gmatch '()\n'
    local row = 1
    local start = 1
    local line = {
        row = row,
        start = start,
        end_ = line_ends() --[[@as integer]],
    }

    return function()
        local end_ = line_ends() --[[@as integer]]
        if not end_ then
            return ---@diagnostic disable-line: missing-return-value
        end
        local prev_line = line
        row = row + 1
        line = {
            row = row,
            start = prev_line.end_ + 1,
            end_ = end_,
        }
        return prev_line, line
    end
end

---Parse and info document node.
---@param text string
---@return info.doc.Document?
function M.parse(text)
    local caps = manual_pattern:match(text) ---@type info.parser.Captures?
    if not caps then
        return
    end

    local file_name = caps.header.file.value.text
    local menu_entries = {}
    local xreferences = {}
    local lines = iter_lines(text)
    local line, next_line = lines()

    for _, el in ipairs(caps.elements) do
        while not (el.start >= line.start and el.start <= line.end_) do
            line, next_line = lines()
            assert(line, next_line, 'no elements at the final line')
        end

        local xref = build_xref(el, file_name, {
            start_line = line.row,
            start_offset = line.start,
            end_line = el.end_ <= line.end_ and line.row or next_line.row,
            end_offset = el.end_ <= line.end_ and line.start or next_line.start,
        })
        if el.type == ElementType.MenuEntry then
            table.insert(menu_entries, xref)
        elseif el.type == ElementType.XReference then
            table.insert(xreferences, xref)
        end
    end

    local file = caps.header.file
    local node = caps.header.node
    local next = caps.header.next
    local prev = caps.header.prev
    local up = caps.header.up

    local header_offset = {
        start_line = 1,
        start_offset = 1,
        end_line = 1,
        end_offset = 1,
    }

    ---@type info.doc.Document
    return {
        header = {
            file = {
                range = calc_range(file, header_offset),
                target = {
                    range = calc_range(file.value, header_offset),
                    text = file.value.text,
                },
            },
            node = {
                range = calc_range(node, header_offset),
                target = {
                    range = calc_range(node.value, header_offset),
                    text = node.value.text,
                },
            },
            next = next and build_relation(next, file_name, header_offset),
            prev = prev and build_relation(prev, file_name, header_offset),
            up = up and build_relation(up, file_name, header_offset),
        },
        menu = {
            header = {},
            entries = menu_entries,
        },
        references = xreferences,
    }
end

---@param ref info.doc.Reference
---@return info.Manual.XRef
local function format_ref(ref)
    ---@type info.Manual.XRef
    return {
        range = ref.range,
        label = ref.label.text,
        target = {
            file = ref.target.file,
            node = ref.target.node,
        },
    }
end

---Format the result of `parse` to the preferred format for storing as buffer variable.
---@param doc info.doc.Document
---@return info.Manual
function M.as_buffer_data(doc)
    local next = doc.header.next
    local prev = doc.header.prev
    local up = doc.header.up
    ---@type info.Manual
    return {
        file = doc.header.file.target.text,
        node = doc.header.node.target.text,
        menu_entries = map(format_ref, doc.menu.entries),
        xreferences = map(format_ref, doc.references),
        relations = {
            next = next and {
                range = next.range,
                target = next.target,
            },
            prev = prev and {
                range = prev.range,
                target = prev.target,
            },
            up = up and {
                range = up.range,
                target = up.target,
            },
        },
    }
end

return M
