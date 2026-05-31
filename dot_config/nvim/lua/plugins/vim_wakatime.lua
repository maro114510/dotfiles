-- https://github.com/wakatime/vim-wakatime.git

return {
  "wakatime/vim-wakatime",
  event = { "BufReadPost", "BufNewFile" },
  cmd = {
    "WakaTimeApiKey",
    "WakaTimeDebugEnable",
    "WakaTimeDebugDisable",
    "WakaTimeStatusBarEnable",
    "WakaTimeStatusBarDisable",
    "WakaTimeScreenRedrawDisable",
    "WakaTimeScreenRedrawEnable",
    "WakaTimeScreenRedrawEnableAuto",
    "WakaTimeToday",
    "WakaTimeFileExpert",
    "WakaTimeCliLocation",
    "WakaTimeCliVersion",
  },
}
