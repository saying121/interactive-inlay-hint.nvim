local utils = require("interactive-inlay-hint.utils")
local ui = require("interactive-inlay-hint.ui")
local config = require("interactive-inlay-hint.config")

local M = {}

---@param opts inter_inlay_config
M.setup = function(opts)
    config.setup(opts)
end

---Return the inalyhint count
---@return integer
M.interaction_inlay_hint = function()
    local hint_list = vim.lsp.inlay_hint.get({ bufnr = 0, range = utils.select_word() })
    ui.float_ui(hint_list)

    return #hint_list
end

return M
