'#############################################################################
                     ' Utilities for BugSnag module 
'#############################################################################


'***************************************************
'                  Inner utilities
'***************************************************

function BS_GetBasicEvent() as Object
    return {
        "exceptions": [],
        "breadcrumbs": [],
        "request": {},
        "threads": [],
        "context": "",
        "groupingHash": "",
        "incomplete": true,
        "unhandled": true,
        "severity": "",
        "severityReason": {},
        "user": {},
        "app": {},
        "device": {},
        "session": {},
        "metaData": {} 'configure in future if will be needed;
    }
end function

'TODO: can be implemented in the future for sending more than 1 error event together;
function BS_ConstructBasicEventsArray(quantity = 1 as Integer) as Object
    events = []
    for i = 0 to i < quantity
        'events.Push(m.GetBasicEvent())
        
        'events[i] = m.GetBasicEvent()
    end for
    
    return events
end function

function BS_GetFirmwareVersion() As String
    deviceInfo = CreateObject("roDeviceInfo")
    firmware = deviceInfo.GetVersion()
    
    return firmware.Mid(2, 1) + "." + firmware.Mid(4, 2)
end function


'***************************************************
'                 Outer utilities
'***************************************************

'RBMN-20660: configuring session values for BugSnag;
sub BS_SetupGlobalSessionValues()
    bs_sessionValues = {
        "id": CreateObject("roDeviceInfo").GetRandomUUID(),
        "startedAt": CreateObject("roDateTime").ToISOString(),
        "events": {
            "handled": 0,
            "unhandled": 0
        }
    }

    m.global.AddField("bs_sessionValues", "assocarray", false)
    m.global.bs_sessionValues = bs_sessionValues
end sub

sub BS_AddBreadcrumb(name as String, eventType = "" as String, metaData = {} as Object, checkDuplicates = false)
    globalAA = GetGlobalAA()
    bs_breadcrumbs = globalAA.global.bs_breadcrumbs
    
    'to avoid duplicates in a row;
    if checkDuplicates
        if bs_breadcrumbs.Peek().name = name then return
    end if
    
    breadcrumb = {
        "timestamp": CreateObject("roDateTime").ToISOString(),
        "name": name,
        "type": eventType,
        "metaData": metaData
    }
    bs_breadcrumbs.Push(breadcrumb)
    
    if bs_breadcrumbs.Count() > 10 then bs_breadcrumbs.Shift()
    globalAA.global.bs_breadcrumbs = bs_breadcrumbs
end sub

sub BS_RemoveBreadcrumb()
    globalAA = GetGlobalAA()
    bs_breadcrumbs = globalAA.global.bs_breadcrumbs
    bs_breadcrumbs.Pop()
    globalAA.global.bs_breadcrumbs = bs_breadcrumbs
end sub

'Increasing handled and unhandled requests counters;
sub BS_IncreaseAPIEventsCounter(isHandled as boolean)
    globalAA = GetGlobalAA()
    bs_sessionValues = globalAA.global.bs_sessionValues
    if isHandled
        bs_sessionValues.events.handled++
    else
        bs_sessionValues.events.unhandled++
    end if
    
    globalAA.global.bs_sessionValues = bs_sessionValues
    m.bugsnagConsumer.sessionValues = bs_sessionValues
end sub
