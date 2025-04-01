---@class inter_inlay_keymaps
---@field goto_def? string
---@field hover? string

---@class inter_inlay_config
---@field keymaps? inter_inlay_keymaps
---@field hover_hi? string
---@field win_opts vim.api.keyset.win_config

local M = {}

---@type inter_inlay_config
local default = {
    keymaps = {
        goto_def = "gd",
        hover = "K",
    },
    hover_hi = "LspReferenceText",
    ---@type vim.api.keyset.win_config
    win_opts = {
        width = 80,
        height = 40,
    },
}

M.values = default

---@param opts inter_inlay_config
M.setup = function(opts)
    M.values = vim.tbl_deep_extend("force", default, opts or {})
end

return M
