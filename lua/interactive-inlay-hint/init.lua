local inlay_hint = vim.lsp.inlay_hint
local utils = require("interactive-inlay-hint.utils")
local ui = require("interactive-inlay-hint.ui")
local config = require("interactive-inlay-hint.config")

local M = {}

---@param opts inter_inlay_config
M.setup = function(opts)
    config.setup(opts)
end

---@return boolean
M.exists_inlay_hint = function()
    return #inlay_hint.get({ bufnr = 0, range = utils.select_word() }) > 0
end

---Return the inalyhint count
---@return boolean
M.interaction_inlay_hint = function()
    local hint_list = inlay_hint.get({ bufnr = 0, range = utils.select_word() })

    local hint_count = #hint_list
    if hint_count < 1 then
        return false
    end

    if config.values.disable_when(hint_list) then
        return false
    end

    ui.float_ui(hint_list)

    return true
end

return M
