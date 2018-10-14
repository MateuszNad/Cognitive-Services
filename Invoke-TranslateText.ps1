function Invoke-TranslateText {
    param(
        # Text który ma zostać przetłumaczony
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [string]$Text,
        # Przelacznik Translate aby przetlumaczyc tekst z zmiennej $Text
        [Parameter(ParameterSetName = 'Translate')]
        [switch]$Translate,
        # Przelacznik Dictionary aby sprawdzić słowo z zmiennej $Text
        [Parameter(ParameterSetName = 'Dictionary')]
        [switch]$Dictionary,
        # Klucz do usługi Translate Text
        [Parameter(Mandatory)]
        [string]$Key
    )
    DynamicParam {
        #$Dictionary = $true
        # Pobranie aktualnej listy jezyków i przygotowanie pod ValidateSet
        if ($translate) {
            $type = 'translation'
        }
        if ($dictionary) {   
            $type = 'dictionary'
        }

        [array]$listLang = @()
        $ResponseApi = Invoke-RestMethod -Uri 'https://api.cognitive.microsofttranslator.com/languages?api-version=3.0' 
        $tagLang = ($ResponseApi.$type | Get-Member -MemberType NoteProperty).Name
        $tagLang | Foreach-Object {                 
            if ((($ResponseApi.$type).$_.name).Length -ne 0) {
                $objLang = New-Object PSObject
                $objLang | Add-Member -MemberType NoteProperty -Name Name -Value ($ResponseApi.dictionary).$_.name
                $objLang | Add-Member -MemberType NoteProperty -Name Tag -Value $_
                $listLang += $objLang
            } 
        }
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Parametr -To
        $ParameterNameTo = 'To'
        $acTo = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $paTo = New-Object System.Management.Automation.ParameterAttribute
        $paTo.Mandatory = $true
        $paTo.Position = 3

        # Add the attributes to the attributes collection
        $acTo.Add($paTo)
        $ValidateSetAttributeTo = New-Object System.Management.Automation.ValidateSetAttribute($($listLang | Select-Object -ExpandProperty Name))
        $acTo.Add($ValidateSetAttributeTo)

        $RuntimeParameterTo = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterNameTo, [string[]], $acTo)
        $RuntimeParameterDictionary.Add($ParameterNameTo, $RuntimeParameterTo)
       
        if ($Dictionary) {
            #Parametr -From dla Dictonary
            $ParameterNameFrom = 'From'
            $acFrom = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $paFrom = New-Object System.Management.Automation.ParameterAttribute
            $paFrom.Position = 4
            $paFrom.ParameterSetName = 'Dictionary'
            $paFrom.Mandatory = $true

            # Add the attributes to the attributes collection
            $acFrom.Add($paFrom)
            $ValidateSetAttributeFrom = New-Object System.Management.Automation.ValidateSetAttribute($($listLang | Select-Object -ExpandProperty Name))
            $acFrom.Add($ValidateSetAttributeFrom)

            $RuntimeParameterFrom = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterNameFrom, [string[]], $acFrom)
            $RuntimeParameterDictionary.Add($ParameterNameFrom, $RuntimeParameterFrom)
        }
        return $RuntimeParameterDictionary
    }

    begin {
        $To = $PsBoundParameters[$ParameterNameTo]
        $From = $PsBoundParameters[$ParameterNameFrom]
        
        [string]$param = ''
        [string]$host = "https://api.cognitive.microsofttranslator.com"
        
        if ($translate) {
            [string]$path = "/translate?api-version=3.0"
            [string]$param = ($To | ForEach-Object {("&to=$(($listLang | Where-Object Name -eq $_).tag)")}) -join ''

        }
        if ($dictionary) {   
            [string]$path = "/dictionary/lookup?api-version=3.0"
            [string]$param = "$(($From | ForEach-Object {("&from=$(($listLang | Where-Object Name -eq $_).tag)")}) -join '')$(($To | ForEach-Object {("&to=$(($listLang | Where-Object Name -eq $_).tag)")}) -join '')"
        }
        # Zbudowanie pełnego uri
        [string]$uri = $host + $path + $param
    }
    process {
        $Body = @{} | Select-Object Text
        $Body.Text = $Text 
        $JsonBody = $Body | ConvertTo-Json 

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Ocp-Apim-Subscription-Key", $Key)
        Invoke-RestMethod -Uri $uri -Headers $headers -Body "[$JsonBody]" -ContentType "application/json; charset=utf-8" -Method Post 
    }
    end {

    }
}    

# Tutaj wklejamy klucz
$Key = ''

# Tłumaczenie słów w słowniku 
'chmura', 'świetnie' | Invoke-TranslateText -Dictionary -to English -From Polish -Key $Key

# normalizedSource displaySource translations
# ---------------- ------------- ------------
# chmura           chmura        {@{normalizedTarget=cloud; displayTarget=cloud; posTag=NOUN; confidence=1,0; prefixWord=; backTranslations=System.Object[]}}
# świetnie         świetnie      {@{normalizedTarget=great; displayTarget=great; posTag=ADJ; confidence=0,4832; prefixWord=; backTranslations=System.Object[]}, @{normalizedTarget=brilliantly; displayTarget=brilliantly; posTag=A...


# Tłumaczenie wyrażenia
'Poznaje wszystkie usługi w Azure dzięki Chmurowisko.pl' | Invoke-TranslateText -Translate -To English -Key $Key

# detectedLanguage           translations
# ----------------           ------------
# @{language=pl; score=0,88} {@{text=Explores all the services in Azure with Chmurowisko.pl; to=en}}