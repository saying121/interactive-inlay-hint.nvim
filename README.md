# Interactive With Inalyhint

<https://github.com/user-attachments/assets/6bba9b18-de28-4d9d-9112-52cfe1fcb735>

## Installation

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
    "saying121/interactive-inlay-hint.nvim",
    event = "LspAttach",
    config = function()
        local inter_inlay = require("interactive-inlay-hint")
        inter_inlay.setup({
            keymaps = {
                declaration = "gD",
                definition = "gd",
                typeDefinition = "gY",
                implementation = "gI",
                hover = "K",
            },
            hover_hi = "LspReferenceText",
            lsp_hint = "⚡",
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
            --     inter_inlay.interaction_inlay_hint()
            -- else
            --     vim.lsp.buf.hover({ border = "single" })
            -- end
        end)
    end,
}
```

## Credits

Inspired by [interactive-inlay.nvim](https://github.com/llllvvuu/interactive-inlay.nvim)
