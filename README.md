# info.nvim

Read [`Info`][info] manuals inside Neovim.

## dependencies

- GNU [`info`][info-cli] command-line tool. Version 7.x is recommended.

## `info` URIs

Example:

```
info://file.info/node?line=15
```

Where:
- `file.info` is the name of the file/manual
- `/node` is the specific node visited (if the node is omitted then
  default to `Top`)
- Supports `line` as a query parameter (jump to this line in the node).


## TODO

- [ ] Docs
  - [ ] Usage/Commands/Keymaps
  - [ ] `info-nvim.txt`
  - [ ] Differences with [info.vim]
- [x] Support `node` as a command argument: `:Info coreutils ls`
- [x] Support `dir` entries
- [x] Commands for navigating to relative nodes (prev, next, up)
- [ ] Set buffer commands
  - [ ] Show cross-references
  - [ ] Show menu entries
- [ ] Set up buffer keymaps
  - [x] `K`: go to node under cursor
  - [x] `gp`: go 'prev'
  - [x] `gn`: go 'next'
  - [x] `gu`: go 'up'
  - [ ] `gO`: show various symbols
    - Headings
    - Menu entries
    - Cross-references
    - Footnotes
- [ ] Parsing
  - [x] Line positions for cross-references
  - [x] Headers (all levels)
  - [ ] Text enclosed in special quotes (`‘’`).
- [ ] Highlight/stylize buffer
    - [ ] Conceal `File` and `Node` keys in manual header like `info` does
    - [ ] Conceal characters
    - [ ] Virtual text for headings (extends across the screen length)
    - [x] Cross References: label / (file)node
    - [x] Footnotes: Header
    - [x] Headings (all levels)
    - [x] Menu entries and Menu header

### Backlog

Parse the main `dir` index (`info --file dir`) and create a mapping for
all the menu entries. This can help to:

- Provide completions for the `:Info` editor command.
- Better resolution for topics (`:Info dir` and `:Info info` give
  different results compared to `info dir` and `info info`)

## Developing/Testing

Use `info`'s `--debug=3` flag to get more output about the how `info`
finds Info manuals (see `info --usage info`).

## References

- [GNU Info reader][info]
- [Info.vim][info.vim]: Read and navigate Info files in Vim

[info]: https://www.gnu.org/software/emacs/manual/html_node/info/index.html
[info-cli]: https://www.gnu.org/software/texinfo/manual/info-stnd/html_node/index.html#Top
[info.vim]: https://github.com/HiPhish/info.vim.git
