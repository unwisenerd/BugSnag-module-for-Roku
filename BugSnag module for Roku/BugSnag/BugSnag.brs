'#############################################################################
        ' Module for BugSnag - errors tracking and reporting tool
        'version: 1.0
'#############################################################################
Function NewBugSnagConsumer(sender as Object, msgPort = invalid as Object)
    return InitBugSnagConsumer(sender, msgPort)
End Function

Function InitBugSnagConsumer(sender = invalid as Object, newMsgPort = invalid as Object)
    this = {}

    this.debug = true
    if newMsgPort = invalid
        this.mMessagePort = CreateObject("roMessagePort")
    else
        this.mMessagePort = newMsgPort
    end if
    this.deviceInfo         = CreateObject("roDeviceInfo")
    this.appInfo            = CreateObject("roAppInfo")
    this.sender             = sender

    this.NewReport          = BS_NewReport
    this.SendReport         = BS_SendReport
    this.FormHeaders        = BS_FormHeaders
    this.AddDefaultHeaders  = BS_AddDefaultHeaders
    this.AddCustomHeaders   = BS_AddCustomHeaders
    this.FormJSONReport     = BS_FormJSONReport
    this.AddDefaultValues   = BS_AddDefaultValues
    this.AddCustomValues    = BS_AddCustomValues
    this.AddDeviceInfo      = BS_AddDeviceInfo
    this.AddAppInfo         = BS_AddAppInfo
    this.AddUserInfo        = BS_AddUserInfo
    this.AddSeverityReason  = BS_AddSeverityReason
    this.AddThreads         = BS_AddThreads
    this.AddRequest         = BS_AddRequest
    this.AddExceptions      = BS_AddExceptions
    this.AddNotifierInfo    = BS_AddNotifierInfo
    
    this.xfers              = []
    
    'Configurable from outside
    this.endpoint           = ""
    this.apiKey             = ""
    this.payloadVersion     = 5
    this.releaseStage       = ""
    this.breadcrumbs        = []
    
    this.sessionValues      = {}
    this.maxXfers           = 10
    
    'Utilities
    this.GetFirmwareVersion        = BS_GetFirmwareVersion
    this.ConstructBasicEventsArray = BS_ConstructBasicEventsArray
    this.GetBasicEvent             = BS_GetBasicEvent
    
    return this
End Function

function BS_NewReport(httpRequest as Object, response as Object, exceptionParams = {} as Object)
    if m.debug then ?"------------PROCEEDING NEW REPORT TO BUGSNAG------------"
    
    m.httpRequest = httpRequest
    m.response = response
    m.exceptionParams = exceptionParams
    
    reportHeaders = m.FormHeaders()
    reportJSON = m.FormJSONReport()
    
    result = m.SendReport(reportHeaders, FormatJSON(reportJSON))
    if m.debug then ?"BS_NewReport---------RESULT------",result
    
    while m.xfers.Count() > m.maxXfers
        m.xfers.Shift() ' get rid of the oldest xfers
    end while
end function

function BS_SendReport(reportHeaders as Object, reportJSON as String) as Boolean
    if reportHeaders <> invalid and reportHeaders.Count() > 0 and reportJSON.Len() > 0
        xfer = CreateObject("roURLTransfer")
        xfer.SetPort(m.mMessagePort)
        xfer.SetURL(m.endpoint)
        xfer.SetHeaders(reportHeaders)
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        m.xfers.Push(xfer)
        ?"reportHeaders-------------",reportHeaders
        ?"reportJSON---------apiKey---",reportJSON
        result = xfer.AsyncPostFromString(reportJSON) 
        
        return result
    end if
    
    if m.debug then ?"------------REPORT HEADERS or REPORT JSON WERE SET INCORRECTLY------------"
    return false
end function

function BS_FormHeaders() as Object
    headers = {}
    m.AddDefaultHeaders(headers)
    m.AddCustomHeaders(headers)
    
    return headers
end function

function BS_AddDefaultHeaders(headers = {} as Object) as Object
    defaultHeaders = {
        "Bugsnag-Api-Key": m.apiKey,
        "Bugsnag-Payload-Version": m.payloadVersion.ToStr()
    }
    
    headers.Append(defaultHeaders)
    return headers
end function

function BS_AddCustomHeaders(headers = {} as Object) as Object
    customHeaders = {
        "Content-Type": "application/json"
    }
    
    headers.Append(customHeaders)
    return headers
end function

function BS_FormJSONReport() as Object
    reportJSON = {
        "apiKey": m.apiKey,
        "payloadVersion": m.payloadVersion,
        "events": [m.GetBasicEvent()]
        "notifier": m.AddNotifierInfo()
    }
    
    reportJSON.events[0]["severity"] = m.exceptionParams.severity
    reportJSON.events[0]["context"] = m.exceptionParams.context
    reportJSON.events[0]["groupingHash"] = m.exceptionParams.groupingHash
    
    m.AddDefaultValues(reportJSON)
    m.AddCustomValues(reportJSON)

    return reportJSON
end function

function BS_AddDefaultValues(reportJSON = {} as Object) as Object
    reportJSON.events[0].session = m.sessionValues
    reportJSON.events[0].device = m.AddDeviceInfo()
    reportJSON.events[0].app = m.AddAppInfo()
    reportJSON.events[0].user = m.AddUserInfo()

    return reportJSON
end function

function BS_AddDeviceInfo() as Object
    uiResolution = m.deviceInfo.GetUIResolution()
    return {
        "id": m.deviceInfo.GetChannelClientId(),
        "manufacturer": "Roku",
        "model": m.deviceInfo.GetModelDisplayName(),
        "modelNumber": m.deviceInfo.GetModel(),
        "osName": "Roku OS",
        "osVersion": m.GetFirmwareVersion(),
        "generalMemoryLevel": m.deviceInfo.GetGeneralMemoryLevel(),
        "uiResolution": uiResolution.height.ToStr() + "x" + uiResolution.width.ToStr()
        "time": CreateObject("roDateTime").ToISOString()
    }
end function

function BS_AddAppInfo() as Object
    return {
        "id": m.deviceInfo.GetChannelClientId(),
        "type": "Roku - BrightScript",
        "version": m.appInfo.GetVersion(),
        "releaseStage": m.releaseStage
    }
end function

function BS_AddUserInfo() as Object
    return {
        "id": m.deviceInfo.GetIPAddrs().eth1
    }
end function

function BS_AddCustomValues(reportJSON = {} as Object) as Object
    reportJSON.events[0]["severityReason"] = m.AddSeverityReason()
    reportJSON.events[0]["threads"] = m.AddThreads()
    reportJSON.events[0]["request"] = m.AddRequest()
    reportJSON.events[0]["breadcrumbs"] = m.breadcrumbs
    reportJSON.events[0]["exceptions"] = m.AddExceptions()
    
    return reportJSON
end function

function BS_AddSeverityReason() as Object
    'TODO: fill this with http status and related configs if needed;
    severityReason = {
        "type": "unhandledError",
        "attributes": {
            "errorType": "E_ERROR",
            "level": "Error",
            "signalType": "SIGSEGV",
            "violationType": "NetworkOnMainThread",
            "errorClass": "ActiveRecord::RecordNotFound"
        }
    }
    
    return severityReason
end function

function BS_AddThreads() as Object
    threads = []
    thread = {
        "id": m.exceptionParams.groupingHash,
        "name": m.exceptionParams.groupingHash,
        "errorReportingThread": true,
        "stacktrace": [
            {
              "file": m.exceptionParams.groupingHash,
              "method": m.httpRequest.functionName,
              "inProject": true,
            }
        ],
        "type": "Roku"
    }
    threads.Push(thread)
    
    return threads
end function

function BS_AddRequest() as Object
    if m.httpRequest = invalid then return {}
    
    return {
        "clientIp": m.deviceInfo.GetIPAddrs().eth1,
        "headers": m.httpRequest.headers,
        "httpMethod": m.httpRequest.method,
        "url": m.httpRequest.url,
        "referer": m.httpRequest.url   
    }
end function

function BS_AddExceptions() as Object
    exceptions = []
    exception = {
        "errorClass": "API request error (response code - " + m.response.responseCode.ToStr() + ")",
        "message": m.response.response,
        "stacktrace": [
            {
                "file": m.exceptionParams.groupingHash,
                "method": m.httpRequest.functionName,
                "inProject": true,
            }
        ],
        "type": "Roku"
    }
    exceptions.Push(exception)
    
    return exceptions
end function

function BS_AddNotifierInfo() as Object
    return {
        "name": "Bugsnag Roku",
        "version": "1.0",
        "url": m.notifierLibraryUrl
    }
end function
