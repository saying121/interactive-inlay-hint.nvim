---@class inter_inlay_keymaps
---@field declaration? string
---@field definition? string
---@field typeDefinition? string
---@field implementation? string
---@field hover? string

---@class inter_inlay_config
---@field keymaps? inter_inlay_keymaps
---@field hover_hi? string
---@field ui_select? boolean
---@field win_opts vim.api.keyset.win_config
---Disable when return true
---@field disable_when? fun(hint_list: vim.lsp.inlay_hint.get.ret[]): boolean

local M = {}

---@type inter_inlay_config
local default = {
    keymaps = {
        declaration = "gD",
        definition = "gd",
        typeDefinition = "gy",
        implementation = "gI",
        hover = "K",
    },
    hover_hi = "LspReferenceText",
    ui_select = false,
    lsp_hint = "⚡",
    ---@type vim.api.keyset.win_config
    win_opts = {
        width = 80,
        height = 40,
    },
    disable_when = function(_)
        return false
    end,
}

M.values = default

---@param opts inter_inlay_config
M.setup = function(opts)
    M.values = vim.tbl_deep_extend("force", default, opts or {})
end

return M
