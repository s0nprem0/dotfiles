function getPercentage(msg) {
    var match = msg.match(/(\d+)%/)
    return match ? parseInt(match[1]) : -1
}

function getPrefix(msg) {
    var match = msg.match(/^(.*?)\s+\d+%/)
    return match ? match[1] : msg
}

function getPercentText(msg) {
    var match = msg.match(/(\d+%)/)
    return match ? match[1] : ""
}

function getIcon(msg) {
    var lower = msg.toLowerCase()
    if (lower.includes("volume")) {
        if (lower.includes("mute")) return "󰝟"
        return "󰕾"
    }
    if (lower.includes("mic")) {
        if (lower.includes("mute")) return "󰍭"
        return "󰍬"
    }
    if (lower.includes("kbd brightness") || lower.includes("kbdbrightness")) return "󰌶"
    if (lower.includes("brightness")) return "󰃠"
    return ""
}
