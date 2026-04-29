# info.nvim

Read [`Info`][info] manuals inside Neovim.

## Dependencies

- GNU [`info`][info-cli] command-line tool (version >=7.0).

## Usage and Features

### Editor commands

Use `:Info` to open an info manual:

- `:Info`: opens the top level `dir` menu (like `$ info`)
- `:Info topic`: open the menu entry in `dir` that matches `topic` (like `$ info topic`)
- `:Info file node`: open the manual for `node` in the file `file` (like `$ info --file file --node node`)
- `:Info!`: open the page for the reference/word under the cursor

Examples:

```vim
:Info " Open '(dir)Top'
:Info bash " Open '(bash)Top'
:Info ls "Open '(coreutils)ls invocation'
:Info gzip Adavanced\ Usage " Open '(gzip)Adavanced Usage', note that spaces need to be escaped
:set keywordprg=:Info! " Open info manuals with `K`
```

### Default Keymaps

- `q`: Close window
- `gn`/`<Plug>(info-next-node)`: Go to page pointed by `Next`
- `gp`/`<Plug>(info-prev-node)`: Go to page pointed by `Prev`
- `gu`/`<Plug>(info-up-node)`: Go to page pointed by `Up`
- `gO`/`<Plug>(info-toc)`: Show the table of contents

Additionally, you can use `K` to open the Info manual for the reference
under the cursor.

All keymaps are local to Info buffers.

### health

Run system checks (`:h health`).

```vim
checkhealth info
```

## References

- [GNU Info reader][info]
- [Info.vim][info.vim]: Read and navigate Info files in Vim

[info]: https://www.gnu.org/software/emacs/manual/html_node/info/index.html
[info-cli]: https://www.gnu.org/software/texinfo/manual/info-stnd/html_node/index.html#Top
[info.vim]: https://github.com/HiPhish/info.vim.git
