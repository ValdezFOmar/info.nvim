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

### Reconsider the structure of `info` URLs

```
info://file.info/node?line=15&column=10
```

Where:
- `file.info` is name of the file/manual (keep `.info` suffix?)
- `/node` is the specific node visited (if the node is omitted the
  default to `Top`)
- Supported query parameters are `line` and `column` for jumping to a
  specific part of the given URI

## References

- [GNU Info reader][info]
- [Info.vim][info.vim]: Read and navigate Info files in Vim

[info]: https://www.gnu.org/software/emacs/manual/html_node/info/index.html
[info-cli]: https://www.gnu.org/software/texinfo/manual/info-stnd/html_node/index.html#Top
[info.vim]: https://github.com/HiPhish/info.vim.git
