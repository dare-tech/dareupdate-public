# DARE Update
Public release of DARE Update - NOTE: Product requires a license from DARE Technology Ltd for full use.

Please note that this version is still in Beta. A full wiki will be added in the coming weeks prior to the official release.

## Configuration Profile Customisation

Until the official wikis are available, please refer to the descriptions within the JSON schema for each individual key for an overview of functionality.

When specifying custom prompt messages, please refer to the below table of available variables:

| Variable Name      | Description |
| ----------- | ----------- |
| \*\*Example Text\*\*  | Displays text in bold        |
| \n\n  | Adds a line break       |
| updateButton      | Displays the update button label       |
| logOutButton  | Displays the Log Out button label        |
| deferButton  | Displays the Defer button label        |
| deferCount  | Displays the number of deferrals are remaining        |
| updateCount  | Displays the number of pending cached updates       |
| appName  | Displays the name of the App with a pending update when only 1 App update is pending     |
| appList  | Displays a comma separated list of Apps when more than one App has a pending update       |
| gracePeriod  | Displays the configured grace period. Note: there is no requirement to specify minutes/hours after this as this is already included in the variable      |
