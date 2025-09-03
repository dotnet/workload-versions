## Files

### CredScanSuppressions.json

This file intentionally contains an empty suppressions list. Simply having this file works around a bug in 1ES PT when doing multi-repo checkout and running CredScan. It somehow adds a folder path to `-Sp`, which is the suppression file argument, which is not a valid value for this argument. Simply providing a suppression file (even without any suppressions like this) avoids this problem, as this is the default location for the file, so it uses this one automatically.

For additional information, see: https://eng.ms/docs/cloud-ai-platform/devdiv/one-engineering-system-1es/1es-docs/1es-pipeline-templates/features/sdlanalysis/credscan

### tsaoptions.json

This file provides the basic information about our team internally within AzDO which the TSA task uses to automatically create work items when SDL tasks fail. Per the settings in the file, these work items will be filed within DevDiv (not DncEng).

For additional information, see: https://eng.ms/docs/cloud-ai-platform/devdiv/one-engineering-system-1es/1es-docs/1es-pipeline-templates/features/sdlanalysis/tsasupport