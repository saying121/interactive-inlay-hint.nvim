local api = vim.api
local lsp = vim.lsp
local methods = lsp.protocol.Methods
local lsp_util = lsp.util
local keymap = vim.keymap.set
local utils = require("interactive-inlay-hint.utils")
local tooltip = require("interactive-inlay-hint.tooltip")
local handler = require("interactive-inlay-hint.lsp_handler")
local config = require("interactive-inlay-hint.config")

local M = {}

---@class LabelData
---@field bufnr integer
---@field client_id integer
---@field part string|lsp.InlayHintLabelPart

---@class TextData
---@field row integer
---@field col integer
---@field virt_text string[] [text,hl]

local inlay_list_state = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,

    ---@type TextData[]
    label_text_datas = {},
    labels_width = 0,
    ---@type LabelData[]
    label_raw_datas = {},

    cur_inlay_idx = 0,
    ---@type integer
    ns_id = nil,
    ---@type integer[]
    extmark_ids = {},
    ref_hi = config.values.hover_hi,
}

---@param cur_data LabelData
---@param part lsp.InlayHintLabelPart
function inlay_list_state:keymaps(cur_data, part)
    local client = lsp.get_clients({
        bufnr = cur_data.bufnr,
        client_id = cur_data.client_id,
        method = methods.textDocument_inlayHint,
    })[1]

    keymap(config.values.keymaps.goto_def[1], config.values.keymaps.goto_def[2], function()
        client:request(methods.textDocument_definition, {
            textDocument = { uri = part.location.uri },
            position = part.location.range.start,
        }, handler.goto_definition)
        self:close_hover()
    end, { buffer = self.bufnr })

    keymap(config.values.keymaps.hover[1], config.values.keymaps.hover[2], function()
        if handler.hover_state.winnr ~= nil then
            api.nvim_set_current_win(handler.hover_state.winnr)
            return
        end
        client:request(methods.textDocument_hover, {
            textDocument = { uri = part.location.uri },
            position = part.location.range.start,
        }, function(_, result, _)
            handler.hover(result, self.winnr)
        end)
    end, { buffer = self.bufnr })
end

function inlay_list_state:handle_part()
    for _, value in pairs(config.values.keymaps) do
        -- Del old keymap.
        -- Make sure keymap only in the part that have location
        pcall(vim.keymap.del, value[1], value[2], { buffer = self.bufnr })
    end

    local cur_data = self:cur_data()
    local part = cur_data.part

    ---@type string|lsp.MarkupContent
    local input
    if type(part) == "string" then
        input = part
    else
        input = part.tooltip

        if part.location ~= nil then
            self:keymaps(cur_data, part)
        end
    end

    if input == nil then
        return
    end
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(input, {})

    tooltip:init(markdown_lines, self.winnr)
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
function inlay_list_state:init(hint_list)
    inlay_list_state:clear()

    self.bufnr = api.nvim_create_buf(false, true)

    for i, value in ipairs(hint_list) do
        local label = value.inlay_hint.label
        if i > 1 then
            api.nvim_buf_set_text(self.bufnr, 0, self.labels_width, 0, self.labels_width, { " " })
            self.labels_width = self.labels_width + 1
        end
        if type(label) == "string" then
            ---@type TextData
            local dt = { col = self.labels_width, row = 0, virt_text = { label } }
            api.nvim_buf_set_text(self.bufnr, 0, self.labels_width, 0, self.labels_width, { label })

            self.labels_width = self.labels_width + #label
            table.insert(self.label_text_datas, dt)
            ---@type LabelData
            local lbdt = {
                bufnr = value.bufnr,
                client_id = value.client_id,
                part = label,
            }
            table.insert(self.label_raw_datas, lbdt)
        else
            for _, part in ipairs(label) do
                ---@type TextData
                local dt = { col = self.labels_width, row = 0, virt_text = { part.value } }
            api.nvim_buf_set_text(self.bufnr, 0, self.labels_width, 0, self.labels_width, { part.value })

                self.labels_width = self.labels_width + #part.value

                table.insert(self.label_text_datas, dt)

                ---@type LabelData
                local lbdt = {
                    bufnr = value.bufnr,
                    client_id = value.client_id,
                    part = part,
                }
                table.insert(self.label_raw_datas, lbdt)
            end
        end
    end

    local width = self.labels_width
    local height = 1
    ---@type vim.api.keyset.win_config
    local win_opts = vim.tbl_extend("keep", config.values.win_opts, {
        border = "rounded",
        relative = "cursor",
        row = 1,
        col = -1,
    })
    utils.min_width_height(win_opts, width, height)

    self.winnr = api.nvim_open_win(self.bufnr, true, win_opts)
    api.nvim_win_set_cursor(self.winnr, { 1, 0 })

    api.nvim_create_autocmd({ "WinClosed" }, {
        buffer = self.bufnr,
        callback = function(_)
            tooltip:close_hover()
            handler.hover_state:close_hover()
        end,
    })
    utils.set_win_buf_opt(self.winnr, self.bufnr)

    keymap("n", "q", function()
        self:close_hover()
    end, { buffer = self.bufnr, silent = true })
    keymap("n", "h", function()
        self:update(-1)
    end, { buffer = self.bufnr, silent = true })
    keymap("n", "l", function()
        self:update(1)
    end, { buffer = self.bufnr, silent = true })

    self:update(1)
end

function inlay_list_state:close_hover()
    api.nvim_win_close(self.winnr, true)
end

---@return LabelData
function inlay_list_state:cur_data()
    return self.label_raw_datas[self.cur_inlay_idx]
end

---@param direction -1|1
function inlay_list_state:update(direction)
    if self.cur_inlay_idx == 0 then
        direction = 1
    else
        if direction == -1 and self.cur_inlay_idx == 1 then
            return
        elseif direction == 1 and self.cur_inlay_idx == #self.label_text_datas then
            return
        end
        table.remove(self.label_text_datas[self.cur_inlay_idx].virt_text, 2)
    end

    self.cur_inlay_idx = self.cur_inlay_idx + direction
    local cur_data = self.label_text_datas[self.cur_inlay_idx]
    api.nvim_win_set_cursor(self.winnr, { 1, cur_data.col })
    table.insert(cur_data.virt_text, self.ref_hi)

    self:refresh()

    tooltip:close_hover()
    handler.hover_state:close_hover()

    self:handle_part()
end

function inlay_list_state:clear()
    self.winnr = nil
    self.bufnr = nil

    self.label_text_datas = {}
    self.labels_width = 0
    self.label_raw_datas = {}

    self.cur_inlay_idx = 0
    self.ns_id = nil
end

function inlay_list_state:refresh()
    self.ns_id = api.nvim_create_namespace("inaly-ui")
    for _, id in pairs(self.extmark_ids) do
        api.nvim_buf_del_extmark(self.bufnr, self.ns_id, id)
    end
    self.extmark_ids = {}
    for _, vt in ipairs(self.label_text_datas) do
        local id = api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, vt.col, {
            virt_text = { vt.virt_text },
            virt_text_pos = "overlay",
        })
        table.insert(self.extmark_ids, id)
    end
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
M.float_ui = function(hint_list)
    if #hint_list < 1 then
        return
    end

    inlay_list_state:init(hint_list)
end

---@type lsp.Handler
---@param inlay_hint lsp.InlayHint
local function text_edits_handler(_, inlay_hint, ctx)
    local _ = lsp.get_clients({
        bufnr = ctx.bufnr,
        client_id = ctx.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    if not inlay_hint then
        return
    end

    -- if part then
    --     client:request(methods.textDocument_hover, {
    --         textDocument = { uri = part.location.uri },
    --         position = part.location.range.start,
    --     }, function(_, result, _)
    --         handle_float(result.contents)
    --     end)
    --     return
    -- end
end

---TODO: It can get `textEdits` for insert inalyhint text.
---No interest at the moment.
---
---@param hint vim.lsp.inlay_hint.get.ret
M.req = function(hint)
    local client = lsp.get_clients({
        bufnr = hint.bufnr,
        client_id = hint.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    client:request(methods.inlayHint_resolve, hint.inlay_hint, text_edits_handler, hint.bufnr)
end

return M
