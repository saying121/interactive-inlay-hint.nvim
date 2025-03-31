# Interactive With Inalyhint

<https://github.com/user-attachments/assets/01614c63-4989-4428-92df-3b03169d9792>

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
                goto_def = { "n", "gd" },
                hover = { "n", "K" },
            },
            hover_hi = "LspReferenceText",
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
