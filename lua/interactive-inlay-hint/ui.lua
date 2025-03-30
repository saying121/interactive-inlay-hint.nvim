local api = vim.api
local lsp = vim.lsp
local methods = lsp.protocol.Methods
local lsp_util = lsp.util
local keymap = vim.keymap.set
local utils = require("interactive-inlay-hint.utils")
local tooltip = require("interactive-inlay-hint.tooltip")
local handler = require("interactive-inlay-hint.lsp_handler")

local M = {}

---@type lsp.Handler
---@param inlay_hint lsp.InlayHint
local function lsp_handler(_, inlay_hint, ctx)
    local client = lsp.get_clients({
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

---@class LabelData
---@field bufnr integer
---@field client_id integer
---@field part string|lsp.InlayHintLabelPart

local inlay_list_state = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,

    ---@type string[][]
    label_text_datas = {},
    labels_width = 0,
    ---@type (string|lsp.InlayHintLabelPart)[]
    ---@type LabelData[]
    label_raw_datas = {},

    cur_inlay_idx = 0,
    ---@type integer
    ns_id = nil,
    ---@type integer
    extmark_id = nil,
    ref_hi = "LspReferenceText",
}

function inlay_list_state:handle_part()
    local cur_data = self:cur_data()
    local part = cur_data.part

    ---@type string|lsp.MarkupContent
    local input
    if type(part) == "string" then
        input = part
    else
        input = part.tooltip

        if part.location ~= nil then
            local client = lsp.get_clients({
                bufnr = cur_data.bufnr,
                client_id = cur_data.client_id,
                method = methods.textDocument_inlayHint,
            })[1]

            keymap("n", "gd", function()
                client:request(methods.textDocument_definition, {
                    textDocument = { uri = part.location.uri },
                    position = part.location.range.start,
                }, function(_, result, ctx)
                    handler.goto_definition(_, result, ctx)
                end)
                self:close_hover()
            end, { buffer = self.bufnr })

            keymap("n", "K", function()
                client:request(
                    methods.textDocument_hover,
                    {
                        textDocument = { uri = part.location.uri },
                        position = part.location.range.start,
                    }
                    -- , function(_, result, _)
                    -- end
                )
                -- self:close_hover()
            end, { buffer = self.bufnr })
        end
    end

    if input == nil then
        return
    end
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(input, {})

    tooltip:init(markdown_lines)
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
function inlay_list_state:init(hint_list)
    inlay_list_state:clear()

    self.bufnr = api.nvim_create_buf(false, true)

    for _, value in ipairs(hint_list) do
        local label = value.inlay_hint.label
        if type(label) == "string" then
            self.labels_width = self.labels_width + #label
            table.insert(self.label_text_datas, { label })
            ---@type LabelData
            local lbdt = {
                bufnr = value.bufnr,
                client_id = value.client_id,
                part = label,
            }
            table.insert(self.label_raw_datas, lbdt)
        else
            for _, part in ipairs(label) do
                self.labels_width = self.labels_width + #part.value
                table.insert(self.label_text_datas, { part.value })
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
    self.winnr = api.nvim_open_win(
        self.bufnr,
        true,
        { border = "rounded", relative = "cursor", width = self.labels_width, height = 1, row = 1, col = -1 }
    )
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

    self.ns_id = api.nvim_create_namespace("inaly-ui")
    self.extmark_id = api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, 0, {
        virt_text = self.label_text_datas,
        virt_text_pos = "inline",
    })
    self:update(1)
end

function inlay_list_state:close_hover()
    api.nvim_win_close(self.winnr, true)
    tooltip:close_hover()
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
        table.remove(self.label_text_datas[self.cur_inlay_idx], 2)
    end

    self.cur_inlay_idx = self.cur_inlay_idx + direction
    table.insert(self.label_text_datas[self.cur_inlay_idx], self.ref_hi)

    self:refresh()

    tooltip:close_hover()

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
    self.extmark_id = nil
end

function inlay_list_state:refresh()
    api.nvim_buf_del_extmark(self.bufnr, self.ns_id, self.extmark_id)
    self.extmark_id = api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, 0, {
        virt_text = self.label_text_datas,
        virt_text_pos = "inline",
    })
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
M.float_ui = function(hint_list)
    if #hint_list < 1 then
        return
    end

    inlay_list_state:init(hint_list)
end

---@param hint vim.lsp.inlay_hint.get.ret
M.req = function(hint)
    local client = lsp.get_clients({
        bufnr = hint.bufnr,
        client_id = hint.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    client:request(methods.inlayHint_resolve, hint.inlay_hint, lsp_handler, hint.bufnr)
end

return M
