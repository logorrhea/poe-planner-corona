local toast = {}

function destroy(toast, decay)
    toast.transition = transition.to(toast, {time=decay, alpha=0, onComplete = function() trueDestroy(toast) end })
end

function trueDestroy(toast)
    toast:removeSelf()
    toast = nil
end 

toast.new = function(x, y, text, decay)
    decay = decay or 500
    print(x, y, text, decay)

    local toast = display.newGroup()

    toast.text = display.newText{
        parent = toast,
        text = text,
        x = x, 
        y = y,
        width = display.contentWidth/4,
        height = display.contentWidth/4*(1/2),
        font = system.nativeFont,
    }

    toast.background = display.newRoundedRect( toast, x, y, toast.text.width + 24, toast.text.height + 24, 16 );
    toast.background.strokeWidth = 4
    toast.background:setFillColor(.3, .3, .3)
    toast.background:setStrokeColor(96, 88, 96)

    toast.anchorX = toast.width/2
    toast.anchorY = toast.height/2

    toast.text:toFront()

    timer.performWithDelay(decay, function() destroy(toast, decay) end)
    return toast
end

return toast
