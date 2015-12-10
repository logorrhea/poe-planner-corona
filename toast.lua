local toast = {}

function destroy(toast, decay)
    toast.transition = transition.to(toast, {time=decay, alpha=0, onComplete = function() trueDestroy(toast) end })
end

function trueDestroy(toast)
    toast.descriptions:removeSelf()
    toast:removeSelf()
    toast = nil
end 

toast.new = function(x, y, node, decay)
    decay = decay or 500

    local toast = display.newGroup()
    toast.headerText = display.newText {
        parent = toast,
        text = node.name,
        x = x, 
        y = y,
        --width = display.contentWidth/4,
        --height = display.contentWidth/4*(1/2),
        font = system.nativeFont,
        fontSize = 20,
    }
    toast.headerText.y = y - toast.headerText.height -- adjust position based on text height

    toast.descriptions = display.newGroup()
    local totalTextHeight = toast.headerText.height
    for _, desc in pairs(node.descriptions) do
        local line = display.newText {
            parent = toast,
            x = toast.headerText.x,
            y = toast.headerText.y + totalTextHeight,
            text = desc,
            fontSize = 12,
        }
        totalTextHeight = totalTextHeight + line.height
        toast.descriptions:insert(line)
    end

    toast.background = display.newRoundedRect(toast, x, y, toast.headerText.width + 16, totalTextHeight + 16, 16);
    toast.background.strokeWidth = 4
    toast.background:setFillColor(.3, .3, .3)
    toast.background:setStrokeColor(96, 88, 96)

    print(toast.background.height)

    toast.anchorX = toast.width/2
    toast.anchorY = toast.height/2

    toast.headerText:toFront()
    toast.descriptions:toFront()

    timer.performWithDelay(decay, function() destroy(toast, decay) end)
    return toast
end

return toast
