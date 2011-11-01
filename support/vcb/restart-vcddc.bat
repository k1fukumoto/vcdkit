%ECHO OFF

set log=%~dp0\logs\restart-vcddc.log

echo %date% %time% ^| INFO ^| Start restarting Data-collector service >> %log%

net stop "VMware vCenter Chargeback - VMware Cloud Director DataCollector-Embedded" >> %log%
IF %ERRORLEVEL% NEQ 0 GOTO STOP_ERROR

net start "VMware vCenter Chargeback - VMware Cloud Director DataCollector-Embedded" >> %log%
IF %ERRORLEVEL% NEQ 0 GOTO START_ERROR

echo %date% %time% ^| INFO ^| Data-collector service restarted >> %log%
exit 0

:STOP_ERROR
echo %date% %time% ^| ERROR ^| Failed to stop data-collector service >> %log%
exit 1

:START_ERROR
echo %date% %time% ^| ERROR ^| Failed to start data-collector service >> %log%
exit 2
