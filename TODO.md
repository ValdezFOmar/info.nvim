## TODO

- [x] Move code back to `lua/info` and move the code inside `init.lua`
   to a difference module.
   `init.lua` should only contain the "public interface" and only expose
   functions that can be used by users.
- [ ] Docs
  - [ ] Usage/Commands/Keymaps
  - [ ] `info-nvim.txt`
  - [ ] Differences with [info.vim]
- [x] Support `node` as a command argument: `:Info coreutils ls`
- [x] Support `dir` entries
- [x] Commands for navigating to relative nodes (prev, next, up)
- [ ] ~Set buffer commands~ Don't add buffer commands for now
  - [ ] ~Show cross-references~ Just include them in `gO`
  - [ ] ~Show menu entries~ Just include them in `gO`
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

### Backlog

Parse code blocks, need to figure out a way to do that.

Parse the main `dir` index (`info --file dir`) and create a map for
all the menu entries. This can help to:

- Provide completions for the `:Info` editor command.
- ~Better resolution for topics (`:Info dir` and `:Info info` give
  different results compared to `info dir` and `info info`)~. No longer
  the case.

## Developing/Testing

Use `info`'s `--debug=3` flag to get more output about the how `info`
finds Info manuals (see `info --usage info`).
