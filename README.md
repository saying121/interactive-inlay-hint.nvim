# Interactive With Inalyhint

## Installation

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
    "saying121/interactive-inlay-hint.nvim",
    config = function()
        local inter_inlay = require("interactive-inlay-hint")
        inter_inlay.setup({
            win_opts = {
                width = 80,
                height = 40,
            },
        })
        vim.keymap.set({ "n", "x" }, "K", function()
            if inter_inlay.interaction_inlay_hint() == 0 then
                vim.lsp.buf.hover({ border = "single" })
            end
            -- or
            -- if inter_inlay.exists_inlay_hint() then
            --     require("interactive-inlay-hint").interaction_inlay_hint()
            -- else
            --     vim.lsp.buf.hover({ border = "single" })
            -- end
        end)
    end,
}
```

## Credits

Inspired by [interactive-inlay.nvim](https://github.com/llllvvuu/interactive-inlay.nvim)
