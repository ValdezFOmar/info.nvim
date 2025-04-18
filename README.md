# info.nvim

Read [`Info`][info] manuals inside Neovim.

## dependencies

- GNU [`info`][info-cli] command-line tool. Version 7.x is recommended.

## TODO

- [ ] Docs
  - [ ] Usage/Commands/Keymaps
  - [ ] Differences with [info.vim]
- [ ] Support `node` as a command argument: `:Info coreutils ls`
- [ ] Support `dir` entries
- [ ] Support for `--usage` option (`info --usage info-stnd`)
- [ ] Go to node under cursor (map to `K`?)
- [ ] Commands for navigating to relative nodes (prev, next, up)
- [ ] Highlight buffer
    - [ ] Conceal characters
    - [ ] References
    - [ ] Footnotes
    - [ ] Headings
    - [ ] Menu entries

## References

- [GNU Info reader][info]
- [Info.vim][info.vim]: Read and navigate Info files in Vim

[info]: https://www.gnu.org/software/emacs/manual/html_node/info/index.html
[info-cli]: https://www.gnu.org/software/texinfo/manual/info-stnd/html_node/index.html#Top
[info.vim]: https://github.com/HiPhish/info.vim.git
