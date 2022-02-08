*** Settings ***
Library         RPA.Robocorp.Vault
Library         RPA.Browser.Selenium
Library         RPA.Excel.Files
Library         RPA.HTTP
Library         RPA.FileSystem
Library         RPA.Tables
Library         RPA.Excel.Files
Library         RPA.JSON
Library         String
Library         Collections
Library         Process
Library         XML
Library         OperatingSystem
Library         RPA.PDF
Library         DateTime
Library         RPA.Archive
Library         RPA.Dialogs

*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.
...               The Bot has been implemented by Jacopo Maggio for Robocorp Certificate level II

*** Variables ***
${CSV_URL}  https://robotsparebinindustries.com/orders.csv

*** Variables ***
${OUTPUT_DIR}  output
${RECEPIT_DIRECTORY}  recepit

*** Keywords ***
Open Ordering Site
	${siteUrl} =     RPA.Robocorp.Vault.Get Secret      site_url
    Log    ${siteUrl}
    Open Available Browser    ${siteUrl}[url]
    Log     Open Ordering Site Done

*** Keywords ***
Close Popup
    Click Element If Visible    alias:site.popup_ok
    Log     Close Popup Done

*** Keywords ***
Ger Order List
	[Arguments]     ${csvUrl}
    IF    '${csvUrl}' == '${EMPTY}'
        ${csvUrl}=    Set Variable    https://robotsparebinindustries.com/orders.csv
        Log    ${csvUrl}
    END
    Download    ${csvUrl}  overwrite=True  target_file=${OUTPUT_DIR}${/}orders.csv
    ${check}=    Does File Exist    ${OUTPUT_DIR}${/}orders.csv
    IF    ${check} != "True"
        Download    ${CSV_URL}  overwrite=True  target_file=${OUTPUT_DIR}${/}orders.csv
    END
    ${table}=    Read table from CSV    ${OUTPUT_DIR}${/}orders.csv
    Log     ${table}
    Log     Done
    [Return]    ${table}

*** Keywords ***
Fill Form
    [Arguments]     ${order}
    Select From List By Value    xpath://select[@id='head']    ${order}[Head]
    Click Element     xpath://input[@id='id-body-${order}[Body]']
    Input Text     xpath:/html/body/div/div/div[1]/div/div[1]/form/div[3]/input     ${order}[Legs]
    Input Text     xpath://input[@id='address']     ${order}[Address]
    Log     Done

*** Keywords ***
Preview Robot
    Click Button     xpath://button[@id='preview']
    Log     Done

*** Keywords ***
Submit Order
    Click Button    xpath://button[@id='order']
    ${continue}=       Is Element Visible    xpath://button[@id='order-another']
    Log     ${continue}
    Log     Done
    [Return]     ${continue}

*** Keywords ***
Save PDF Recepit
    [Arguments]     ${orderNumber}
    Wait Until Element Is Visible    xpath://div[@id='receipt']
    ${recepit}=    RPA.Browser.Selenium.Get Element Attribute    xpath://div[@id='receipt']    outerHTML
    Html To Pdf    ${recepit}    ${OUTPUT_DIR}${/}recepit${orderNumber}.pdf
    Log     Done
    [Return]    ${OUTPUT_DIR}${/}recepit${orderNumber}.pdf

*** Keywords ***
Screenshot robot
    [Arguments]     ${orderNumber}
    Capture Element Screenshot    xpath://div[@id='robot-preview-image']    ${OUTPUT_DIR}${/}image${orderNumber}.png
    Log     Done
    [Return]    ${OUTPUT_DIR}${/}image${orderNumber}.png

*** Keywords ***
Create PDF
    [Arguments]     ${pdf}    ${screenshot}    ${orderNumber}
    ${files}=    Create List
    ...    ${pdf}
    ...    ${screenshot}:x=0,y=0
    Add Files To PDF    ${files}    ${OUTPUT_DIR}${/}${RECEPIT_DIRECTORY}${/}final_recepit${orderNumber}.pdf
    RPA.FileSystem.Remove File    ${pdf}
    RPA.FileSystem.Remove File    ${screenshot}
    Log     Done

*** Keywords ***
End order
    Click Element When Visible     xpath://button[@id='order-another']
    Log     Done

*** Keywords ***
Create ZIP and Clean
	${zipFileName}=    Set Variable    ${OUTPUT_DIR}${/}PDFs.zip
	Archive Folder With Zip
    ...    ${OUTPUT_DIR}${/}${RECEPIT_DIRECTORY}
    ...    ${zipFileName}
	Remove Directory     ${OUTPUT_DIR}${/}${RECEPIT_DIRECTORY}    True
    Log     Done

*** Keywords ***
Collect CSV From User
    Add heading       Insert CSV url. 
    Add heading       If no file will be found in url you provide, ${CSV_URL} will be used
    Add text input    url    label=CSV url
    ${response}=    Run dialog
    [Return]    ${response.url}

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
	${csvUrl}=     Collect CSV From User
    Open Ordering Site
    ${orderList}=    Ger Order List    ${csvUrl}
	Create Directory     ${OUTPUT_DIR}${/}${RECEPIT_DIRECTORY}
    FOR    ${row}    IN    @{orderList}
        Log     ${row}
        Close Popup
        Fill Form    ${row}
        Preview Robot
        FOR    ${i}    IN RANGE    9999999
            ${continue}=    Submit Order
            Log    ${continue}
            Exit For Loop If    "${continue}" == "True"
        END
        
        ${pdf}=    Save PDF Recepit    ${row}[Order number]
        ${screenshot}=    Screenshot robot    ${row}[Order number]
        Create PDF    ${pdf}    ${screenshot}    ${row}[Order number]
        End order
    END
    Create ZIP and Clean
