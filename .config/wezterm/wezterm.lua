
local config = require("config.init")
-- require("config.format")
tab_conf = require("config.tabline")
-- require("config.status")
-- require("config.workspace")

function table_merge(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                table_merge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

-- configとtab_confの辞書の構造体をマージ
local merged_conf = table_merge(config, tab_conf)

return merged_conf

