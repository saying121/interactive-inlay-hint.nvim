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
                typeDefinition = "gy",
                implementation = "gI",
                hover = "K",
            },
            hover_hi = "LspReferenceText",
            lsp_hint = "⚡",
            win_opts = {
                width = 80,
                height = 40,
            },
            -- Example of disabling when there is no additional information
            disable_when = function(hint_list)
                for _, v in ipairs(hint_list) do
                    if type(v.inlay_hint.label) == "table" then
                        return false
                    end
                end
                return true
            end,
        })
        vim.keymap.set({ "n", "x" }, "K", function()
            if not inter_inlay.interaction_inlay_hint() then
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

## Example of use your handler override the plugin's

```lua
local util = lsp.util
local log = vim.lsp.log
local lsp = vim.lsp
local vfn = vim.fn
local api = vim.api
local methods = lsp.protocol.Methods

local function get_locations(split_cmd)
    ---@type lsp.Handler
    local handler = function(_, result, ctx)
        local encoding = "utf-8"
        local client = lsp.get_client_by_id(ctx.client_id)
        if client then
            encoding = client.offset_encoding
        end
        if result == nil or vim.tbl_isempty(result) then
            local _ = log.info() and log.info(ctx.method, "No location found")
            return nil
        end

        if split_cmd then
            vim.cmd(split_cmd)
        end

        if vim.islist(result) then
            util.show_document(result[1], encoding, { focus = true })

            if #result > 1 then
                vfn.setqflist({}, " ", {
                    title = "LSP locations",
                    items = util.locations_to_items(result, encoding),
                })
                vim.cmd("botright copen")
                api.nvim_command("wincmd p")
            end
        else
            util.show_document(result, encoding, { focus = true })
        end
    end

    return handler
end

lsp.handlers[methods.textDocument_definition] = get_locations("vsplit")
lsp.handlers[methods.textDocument_implementation] = get_locations("vsplit")
```

## Credits

Inspired by [interactive-inlay.nvim](https://github.com/llllvvuu/interactive-inlay.nvim)
