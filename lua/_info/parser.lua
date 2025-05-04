local map = vim.tbl_map

local M = {}

local lpeg = vim.lpeg
local S = lpeg.S
local P = lpeg.P
local B = lpeg.B
local Cp = lpeg.Cp
local Ct = lpeg.Ct
local Cg = lpeg.Cg

local START = Cg(Cp(), 'start')
local END = Cg(Cp(), 'end_')

---@enum info.Element
local ElementType = {
    Heading = 'Heading',
    MenuEntry = 'MenuEntry',
    MenuHeader = 'MenuHeader',
    XReference = 'XReference',
    FootNoteHeading = 'FootNoteHeading',
    InlineURI = 'InlineURI',
}
M.ElementType = ElementType

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

---Makes pattern optional (matches 0 or 1 times).
---@param pattern any
---@return vim.lpeg.Pattern
local function O(pattern)
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
        return START * Cgt('value', key * SP * Cpos(text)) * END * O(SP)
    end

    local COMMA = ',' * SP
    local file_name = header_key 'File:'
    local this_node = header_key 'Node:'
    local next_node = header_key 'Next:'
    local prev_node = header_key 'Prev:'
    local up_node = header_key 'Up:'
    local header_desc = START * (1 - MSP) * (1 - P '\n') ^ 1 * END
    local node_header = Cgt('file', file_name)
        * COMMA
        * Cgt('node', this_node)
        * O(COMMA * Cgt('next', next_node))
        * O(COMMA * Cgt('prev', prev_node))
        * O(COMMA * Cgt('up', up_node))
        * O(Cgt('desc', header_desc))
        * SWALLOW_LINE -- Extra text (see `info --file dir`)

    -- NOTE:
    -- The first character might be a colon (':') and should be considered part of the reference
    -- label (i.e. (bash)Builtin Index), so take the first non-space character unconditionally.
    local reference_text = (1 - S ' \t\n') * (P(1) - ':') ^ 0
    local reference_node = (P(1) - S '.,\t\n') ^ 1
    local reference = Cgt('label', Cpos(reference_text))
        * ':'
        * (':' + SP * Cgt('target', Cpos(reference_node)) * O(S '.,'))

    local menu_header = Ctype(ElementType.MenuHeader)
        * B '\n'
        * START
        * '* Menu:'
        * END
        * SWALLOW_LINE -- Menu description

    local line_offset = P '(line' * SP * Cg(lpeg.R '09' ^ 1 / tonumber, 'line') * ')'
    local menu_entry = Ctype(ElementType.MenuEntry)
        * B '\n' -- menu entries only appear at the start of lines
        * START
        * '* '
        * reference
        * END
        * O(O '\n' * SP * line_offset) -- line offset may appear in the next line
        * SWALLOW_LINE -- entry description / comment

    local inline_reference = Ctype(ElementType.XReference)
        * START
        * '*'
        * S 'Nn'
        * 'ote'
        * MSP -- reference can continue the next line
        * reference
        * END

    local footnote_heading = Ctype(ElementType.FootNoteHeading)
        * B '\n   ' -- Footnotes headings seem to always appear at exactly 3 spaces from the start of the line
        * START
        * P '-' ^ 1
        * SP
        * 'Footnotes'
        * SP
        * P '-' ^ 1
        * END
        * SWALLOW_LINE

    local inline_uri = Ctype(ElementType.InlineURI)
        * START
        * '<http'
        * O 's'
        * '://'
        * (P(1) - S ' >\n') ^ 1
        * '>'
        * END

    ---Capture a manual heading
    ---@param level integer
    ---@param char string
    ---@return vim.lpeg.Pattern
    local function heading(level, char)
        return Ctype(ElementType.Heading)
            * Cg(lpeg.Cc(level), 'level')
            * Cg(lpeg.Cc(char), 'char')
            * B '\n'
            * START
            * P(char) ^ 1
            * END
            * '\n'
    end

    local line = Ct(heading(1, '*'))
        + Ct(heading(2, '='))
        + Ct(heading(3, '-'))
        + Ct(heading(4, '.'))
        + Ct(footnote_heading)
        + Ct(menu_header)
        + Ct(menu_entry)
        + Ct(inline_reference)
        + Ct(inline_uri)
        + 1

    return Ct(Cgt('header', node_header) * Cgt('elements', line ^ 0) * -1)
end)()

---@param text string
---@return string
local function fold_spaces(text)
    return (text:gsub('%s+', ' ')) -- Limit return to only one value
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

---@param pos info.parser.Position
---@param line info.iter_lines.Line
---@param next_line info.iter_lines.Line
---@return info.TextRange
local function range_from_lines(pos, line, next_line)
    local start_line = pos.start >= next_line.start and next_line or line
    local end_line = pos.end_ <= line.end_ and line or next_line
    -- `pos` is 1-indexed but the range needs to be 0-indexed
    ---@type info.TextRange
    return {
        start_row = start_line.row,
        start_col = pos.start - start_line.start - 1,
        end_row = end_line.row,
        end_col = pos.end_ - end_line.start - 1,
    }
end

---@param rel info.parser.Header.Pair
---@param this_file string
---@param line info.iter_lines.Line
---@param next_line info.iter_lines.Line
---@return info.doc.Header.Relation
local function build_relation(rel, this_file, line, next_line)
    local file, node = parse_reference(rel.value.text)
    ---@type info.doc.Header.Relation
    return {
        range = range_from_lines(rel, line, next_line),
        target = {
            range = range_from_lines(rel.value, line, next_line),
            file = file or this_file,
            node = node or 'Top',
        },
    }
end

---@param ref info.parser.Reference
---@param this_file string
---@param line info.iter_lines.Line
---@param next_line info.iter_lines.Line
---@return info.doc.Reference
local function build_xref(ref, this_file, line, next_line)
    local label = fold_spaces(ref.label.text)
    local target = ref.target and fold_spaces(ref.target.text) or label
    local file, node = parse_reference(target)
    return {
        range = range_from_lines(ref, line, next_line),
        label = {
            text = label,
            range = range_from_lines(ref.label, line, next_line),
        },
        target = {
            file = file or this_file,
            node = node or 'Top',
            line = ref.line,
            range = ref.target and range_from_lines(ref.target, line, next_line),
        },
    }
end

---@param header info.parser.Header
---@param line info.iter_lines.Line
---@param next_line info.iter_lines.Line
---@return info.doc.Header
local function build_header(header, line, next_line)
    local desc = header.desc
    local file = header.file
    local node = header.node
    local next = header.next
    local prev = header.prev
    local up = header.up
    local file_name = file.value.text

    ---@type info.doc.Header
    return {
        desc = desc and range_from_lines(desc, line, next_line),
        meta = {
            file = {
                range = range_from_lines(file, line, next_line),
                target = {
                    range = range_from_lines(file.value, line, next_line),
                    text = file.value.text,
                },
            },
            node = {
                range = range_from_lines(node, line, next_line),
                target = {
                    range = range_from_lines(node.value, line, next_line),
                    text = node.value.text,
                },
            },
        },
        relations = {
            next = next and build_relation(next, file_name, line, next_line),
            prev = prev and build_relation(prev, file_name, line, next_line),
            up = up and build_relation(up, file_name, line, next_line),
        },
    }
end

---@class info.iter_lines.Line
---@field row integer
---@field start integer
---@field end_ integer

---Iterate over the lines of `text` retrieving the current and next line.
---Yields an additional line at the end to simplify some operations.
---@param text string
---@return fun(): info.iter_lines.Line, info.iter_lines.Line
local function iter_lines(text)
    local line_ends = text:gmatch '()\n'
    local row = 0
    local line = {
        row = row,
        start = 0,
        end_ = line_ends() --[[@as integer]],
    }

    local yielded_extra_line = false
    return function()
        row = row + 1
        local start = line.end_
        local end_ = line_ends() --[[@as integer]]
        if not end_ then
            if not yielded_extra_line then
                yielded_extra_line = true
                end_ = start -- yield empty line
            else
                ---@diagnostic disable-next-line: missing-return-value
                return
            end
        end
        local prev_line = line
        line = {
            row = row,
            start = start,
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

    local lines = iter_lines(text)
    local line, next_line = lines()

    local header = build_header(caps.header, line, next_line)

    local footnote_heading ---@type { range: info.TextRange }?
    local menu_header ---@type { range: info.TextRange }?
    local menu_entries = {} ---@type info.doc.Reference[]
    local xreferences = {} ---@type info.doc.Reference[]
    local headings = {} ---@type info.doc.Heading[]
    local misc = {} ---@type info.doc.Element[]
    local file = caps.header.file.value.text

    for _, el in ipairs(caps.elements) do
        while not (el.start >= line.start and el.start <= line.end_) do
            line, next_line = lines()
            assert(line and next_line, 'no elements at the final line') -- see `iter_lines`
        end
        if el.type == ElementType.MenuHeader then
            menu_header = menu_header or { range = range_from_lines(el, line, next_line) }
        elseif el.type == ElementType.FootNoteHeading then
            footnote_heading = footnote_heading or { range = range_from_lines(el, line, next_line) }
        elseif el.type == ElementType.MenuEntry then
            local xref = el --[[@as info.parser.Reference]]
            menu_entries[#menu_entries + 1] = build_xref(xref, file, line, next_line)
        elseif el.type == ElementType.XReference then
            local xref = el --[[@as info.parser.Reference]]
            xreferences[#xreferences + 1] = build_xref(xref, file, line, next_line)
        elseif el.type == ElementType.Heading then
            local heading = el --[[@as info.parser.Heading]]
            local range = range_from_lines(heading, line, next_line)
            headings[#headings + 1] = {
                char = heading.char,
                level = heading.level,
                range = {
                    -- Capture the previous line as it contains the heading text
                    start_row = range.start_row - 1,
                    start_col = 0,
                    end_col = range.end_col,
                    end_row = range.end_row,
                },
            }
        elseif el.type == ElementType.InlineURI then
            misc[#misc + 1] = {
                type = el.type,
                range = range_from_lines(el, line, next_line),
            }
        end
    end

    ---@type info.doc.Document
    return {
        header = header,
        headings = headings,
        menu = {
            header = menu_header,
            entries = menu_entries,
        },
        references = xreferences,
        footnotes = footnote_heading and { heading = footnote_heading },
        misc = misc,
    }
end

---@param ref info.doc.Reference
---@return info.Manual.XRef
local function format_ref(ref)
    ---@type info.Manual.XRef
    return {
        range = ref.range,
        label = ref.label.text,
        file = ref.target.file,
        node = ref.target.node,
        line = ref.target.line,
    }
end

---Format the result of `parse` to the preferred format for storing as buffer variable.
---@param doc info.doc.Document
---@return info.Manual
function M.as_buffer_data(doc)
    local next = doc.header.relations.next
    local prev = doc.header.relations.prev
    local up = doc.header.relations.up
    ---@type info.Manual
    return {
        file = doc.header.meta.file.target.text,
        node = doc.header.meta.node.target.text,
        menu_entries = map(format_ref, doc.menu.entries),
        xreferences = map(format_ref, doc.references),
        relations = {
            next = next and {
                file = next.target.file,
                node = next.target.node,
            },
            prev = prev and {
                file = prev.target.file,
                node = prev.target.node,
            },
            up = up and {
                file = up.target.file,
                node = up.target.node,
            },
        },
    }
end

return M
