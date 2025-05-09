# info.nvim

Read [`Info`][info] manuals inside Neovim.

## Dependencies

- GNU [`info`][info-cli] command-line tool. Version 7.x is recommended.

## Usage and Features

### Editor commands

Use `:Info` to open an info manual:

- `:Info`: opens the top level `dir` menu (like `$ info`)
- `:Info topic`: open the menu entry in `dir` that matches `topic` (like
  `$ info topic`)
- `Info file node`: open the manual for `node` in the file `file` (like
  `$ info --file file --node node`)

Examples:

```vim
:Info " Open '(dir)Top'
:Info bash " Open '(bash)Top'
:Info ls "Open '(coreutils)ls invocation'
:Info gzip Adavanced\ Usage " Open '(gzip)Adavanced Usage', note that spaces need to be escaped
```

Additionally, there's some buffer-local commands available in Info
buffers:

- `:InfoNext`: Go to the next node pointed by the current node.
- `:InfoPrev`: Go to the previous node pointed by the current node.
- `:InfoUp`: Go up one level, as pointed by the current node.
- `:InfoFollow`: Follow the cross-reference under the cursor, if there's any.
- `:InfoMenu`: Open the `location-list` with all menu entries in the node.
  Selecting a item will open the that menu entry as an Info buffer.

### Default Keymaps

- `q`: Close Info window
- `K`: execute `:InfoFollow`
- `gn`: execute `:InfoNext`
- `gp`: execute `:InfoPrev`
- `gu`: execute `:InfoUp`

All keymaps are local to Info buffers.

### `info` URIs

An Info buffer's name follows the following URI-like scheme:

```
info://file/node?line=15
```

Where:

- `file`: file name
- `node` (optional): node name (default to `Top`)
- `line` (optional): 1-indexed line number to jump to. Is the only query
  parameter supported.

The `file` and `node` parts are percent encoded to avoid conflicts with
reserved characters (e.g. `:Info groff I/O` opens `info://groff.info/I%2fO`)

### health

Run some simple environment checks (`:h health`).

```vim
checkhealth info
```

## References

- [GNU Info reader][info]
- [Info.vim][info.vim]: Read and navigate Info files in Vim

[info]: https://www.gnu.org/software/emacs/manual/html_node/info/index.html
[info-cli]: https://www.gnu.org/software/texinfo/manual/info-stnd/html_node/index.html#Top
[info.vim]: https://github.com/HiPhish/info.vim.git
