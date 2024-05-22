let totalPoints = toscalar(
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.AUTOMATION" and Category == "JobStreams"
    | where RunbookName_s contains "<NAME OF VM UPDATE RUNBOOK>"
    | where ResultDescription contains "LOG;"
    | where ResultDescription contains "<VM PREFIX>"
    | extend split(ResultDescription, ';')
    | extend
        action = ResultDescription[1],
        host = tostring(ResultDescription[2]),
        checktime = tostring(ResultDescription[3]),
        vmImageDefinition = tostring(ResultDescription[5])
    | project TimeGenerated, action
    | where action in ('SKIP', 'UPDATED')
    | summarize count()
);
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AUTOMATION" and Category == "JobStreams"
| where RunbookName_s contains "<NAME OF VM UPDATE RUNBOOK>"
| where ResultDescription contains "LOG;"
| where ResultDescription contains "<VM PREFIX>"
| extend split(ResultDescription, ';')
| extend
    action = ResultDescription[1],
    host = tostring(ResultDescription[2]),
    checktime = tostring(ResultDescription[3]),
    vmImageDefinition = tostring(ResultDescription[5])
| where vmImageDefinition <> ""
| where action in ('SKIP', 'UPDATED')
| project TimeGenerated, action, vmImageDefinition
| summarize count() by bin(TimeGenerated, 15min), vmImageDefinition
| order by TimeGenerated asc
| render areachart with (title="Images in hostpool", xtitle="Time", ytitle="Amount")