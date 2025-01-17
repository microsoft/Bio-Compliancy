# Microsoft 365 BIO compliance Initiative Template

> As this project is specific for the Dutch government the rest of this article will be in Dutch.

> [!NOTE]
> Voor de BIO Compliancy oplossing voor Azure, ga naar dit project: https://github.com/Azure/Bio-Compliancy

Dit project omvat een Initiative Policy Template, welke kan worden vergeleken met Microsoft 365 door middel van [Microsoft 365 Desired State Configuration](https://microsoft365dsc.com) (M365DSC).
Dit project wordt geleverd inclusief een PowerBI dashboard zodat men kan auditen of resources in een Microsoft 365 omgeving voldoen aan de BIO (Baseline informatiebeveiliging Overheid).

De BIO is het basisnormenkader voor informatiebeveiliging binnen alle overheidslagen. De BIO is van toepassing voor de volgende bestuursorganen:

- Rijksdienst
- Provincies
- Waterschappen
- Gemeentes

Dit template is het startpunt om BIO-compliant te worden in een Microsoft 365 cloud omgeving. De template kan worden aangepast aan de eisen en wensen van een specifieke organisatie. De template omvat uitsluitend technische controls. Procesmatige en monitoring controls dienen binnen de organisatie ingevoerd te worden om tot een volledig dekkende BIO compliancy te komen.

Deze template is gebaseerd op BIO Thema-uitwerking Clouddiensten versie 2.2 en CIS control framework.
Meer informatie hierover vind je op: [CIP overheid Cloud thema](https://cip-overheid.nl/productcategorieen-en-workshops/producten?product=Clouddiensten).

## Mappen van BIO Controls op maatregelen in Microsoft 365
De BIO beschrijft een aantal controls en maatregelen welke overheidsinstanties kunnen gebruiken om risico's met betrekking tot informatie beveiliging te mitigeren. Deze maatregelen zijn grotendeels gebaseerd op industriestandaarden, zoals ISO IEC 27002. Meer informatie kan gevonden worden op de website van [BIO Overheid](https://www.bio-overheid.nl/category/producten?product=Handreiking_BIO2_0_opmaat).

De controls en maatregelen beschrijven diverse mitigaties, van technologisch en fysiek tot procedureel en organisatorisch.

> [!IMPORTANT]
> DISLAIMER: Deze BIO assessment tool, gericht op het beoordelen van de technische configuratie van Microsoft 365 (de publieke clouddienst), zal niet alle controls omvatten en dient daarom alleen gebruikt te worden om inzicht te krijgen in potentiële misconfiguratie van een Microsoft 365 tenant in relatie tot BIO controls.

Om tot een betrouwbare mapping te komen, worden verschillende industrie standaarden gebruikt. Ten eerste wordt de ['Center for Internet Security' (CIS) Benchmark for Microsoft 365 (v4.0.0)](https://www.cisecurity.org/benchmark/microsoft_365) gebruikt als het startpunt voor een aanzienlijke hoeveelheid aanbevolen controls. In dit document worden alle controls gemapped op 'CIS Control Safeguards'.
Deze zijn vervolgens door CIS gemapped op de ['ISO 27002 2022'](https://www.cisecurity.org/insights/white-papers/cis-controls-v8-mapping-to-iso-iec2-27002-2022) standaard. De BIO is vervolgens weer gebaseerd op deze 'ISO 27002 2022' standaard, waardoor de cirkel van de CIS Benchmark for Microsoft 365 naar de BIO 2022 rond is.

![alt text](./media/CISforM365ToBIO.png?raw=true "CIS for M365 to BIO mapping")

Naast de CIS Benchmark, zijn de maatregelen om de BIO 2022 controls af te dekken uitgebreid met een aantal Microsoft best practices.

Beperkingen:
- Op dit moment dekt de blueprint de core services in Microsoft 365 af, inclusief Entra ID (Azure AD), Exchange Online, SharePoint Online, OneDrive for Business, Teams, Purview and Defender for Office 365. Ondersteuning voor Intune wordt aan gewerkt.

## Bijdragen

Dit project verwelkomt bijdragen en suggesties. Voor de meeste bijdragen moet je akkoord gaan met een Licentieovereenkomst voor Donateurs (CLA) waarin wordt verklaard dat je het recht hebt om ons het recht te geven om je bijdrage te gebruiken en dat je dat ook daadwerkelijk doet. Ga voor meer informatie naar [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

Wanneer je een pull-verzoek indient, zal een CLA-bot automatisch bepalen of je een CLA moet verstrekken en hoe je het pull-verzoek op de juiste manier afhandelt (bijv. Statuscontrole, opmerking). Volg gewoon de instructies van de bot. Je hoeft dit slechts één keer te doen over alle repo's met behulp van onze CLA.

Dit project heeft de [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/) aangenomen. Zie voor meer informatie over de Code of Conduct de ['Veelgestelde Vragen'](https://opensource.microsoft.com/codeofconduct/faq/) of neem contact op met [opencode@microsoft.com](mailto:opencode@microsoft.com) met eventuele aanvullende vragen of opmerkingen.

## Installatie

### Vereisten

Om deze oplossing te gebruiken, zijn een aantal zaken vereist:
- Tools machine waar de oplossing op uitgevoerd kan worden
  - Deze moet een versie van Windows draaien die nog in support is. Dit kan een client of server versie van Windows zijn.
- Service principal met de juiste rechten.
  - Deze wordt aangemaakt tijdens de stap 'Aanmaken van de service principal'
- Administratieve credentials met 'Global Administrator' rechten
  - Dit account is nodig om de benodigde service principal aan te maken.
- Download de benodigde scripts uit deze repository
  - Kopieer de gedownloade scripts naar een folder op de Tools machine
- [PowerBI Desktop](https://powerbi.microsoft.com/en-us/desktop/) is geïnstalleerd op de Tools machine
  - Deze is te downloaden via de [Microsoft Store](https://aka.ms/pbidesktopstore) of als [handmatige download](https://www.microsoft.com/en-us/download/details.aspx?id=58494)

### Voorbereidingen

Deze voorbereidende stappen hoeven maar maar één keer te worden, tenzij de Tools machine wordt vervangen of de een nieuwe versie van de oplossing wordt gebruikt (wat mogelijk nieuwe rechten vereist voor de service principal).

#### <ins>Installeren benodigde componenten</ins>

De oplossing maakt gebruik van een componenten welke eerste geïnstalleerd moeten worden. Hiervoor is een PowerShell script beschikbaar.

Installeer alle benodigde componenten op de Tools machine door de volgende stappen uit te voeren:
1. Login op de Tools machine
2. Open een elevated 'Windows PowerShell v5.1' window
    - Klik op de 'Start' knop
    - Type 'Powershell'
    - Klik met de rechter muisknop op het 'Windows PowerShell' icoon en  klik op 'Run as Adminstrator'
    - Bevestig dat je het process met Administrator rechten wil draaien door op 'Yes' te klikken
    - Zodra het window geopend is, controleer of er "Administrator: " voor in de titelbalk staat
3. Browse naar de folder waar de scripts naar toe gekopieerd zijn
3. Voer het volgende commando uit: `Get-ChildItem | Unblock-File`
4. Voer het volgende commando uit: `Get-ExecutionPolicy`
5. Als het antwoord van het vorige commando `Restricted` of `AllSigned` is:
    - Controleer of het mogelijk is c.q. is toegestaan om deze setting aan te passen naar `RemoteSigned`
    - Zo ja, voer het volgende commando uit `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned`
    - Zo nee, zorg ervoor dat of de scripts een digitale handtekening krijgen met een vertrouwd certificaat (bij `AllSigned`) of dat scripts (tijdelijk) toegestaan worden (bij `Restricted`)
6. Indien je gebruik maakt van een Windows client OS (Windows 10 of Windows 11):
    - Voer het volgende commando uit `winrm quickconfig`.
    - Dit commando configureert Windows Remoting op de machine, wat nodig is tijdens de analyse.
7. Voer het volgende commando uit: `.\PrepEnvironment.ps1`

#### <ins>Aanmaken van de service principal</ins>

Om in te kunnen loggen in Microsoft 365, maakt deze oplossing gebruik van een service principal/application credential.

Om deze aan te maken, de juiste rechten te geven en een authenticatie certificaat te configureren, voer de volgende stappen uit:
1. Login op de Tools machine
2. Open een elevated 'Windows PowerShell v5.1' window (zie boven voor instructies) en browse naar de folder waar de scripts naar toe gekopieerd zijn
3. Voer het volgende commando uit: `.\PrepBIOServicePrincipal.ps1 -Credential (Get-Credential)`
    - Wanneer het gebruikte account Multi-Factor Authentication gebruikt, kan het zijn dat je nogmaals een password en vervolgens MFA prompt krijgt.

> [!NOTE]
> Dit commando zal een service principal genaamd 'BIOAssessment' aanmaken en een 'self-signed certificate' gebruiken.
> - Als je je eigen naam wil gebruiken, voeg dan de parameter `ServicePrincipalName` toe.
> - Als je je eigen certificaat wil gebruiken, voeg dan de parameter `CertificatePath` toe en verwijs naar de '.cer' file van dat certificaat.

> [!NOTE]
> Als er een error getoond wordt tijdens de 'Admin Consent approval' stap, log dan in in de [Entra ID Admin Portal](https://entra.microsoft.com/), zoek de service principal op en geef [handmatig toestemming](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/grant-admin-consent?pivots=portal#grant-tenant-wide-admin-consent-in-enterprise-apps-pane).

4. Sla de details van de aangemaakte service principal op, welke worden getoond aan het eind van het script. Deze informatie is nodig in volgende stappen.

### Uitvoeren van de assessment

Voor het uitvoeren van de assessment, wordt er eerst een export van de huidige configuratie gemaakt waarna deze vervolgens wordt geanalyseerd en vergeleken met de BIO template. Vervolgens worden de analyse resultaten ingeladen in het Power BI dashboard.

#### <ins>Maken van de export</ins>

1. Login op de Tools machine
2. Open een elevated 'Windows PowerShell v5.1' window (zie boven voor instructies) en browse naar de folder waar de scripts naar toe gekopieerd zijn
3. Voer het volgende commando uit: `.\RunBIOExport.ps1 -ApplicationId <Application Id> -TenantId <tenantname>.onmicrosoft.com -CertificateThumbprint <Certificate Thumbprint>`
    - Vul de juiste gegevens in, zoals deze tijdens het maken van de service principal zijn genoteerd.

#### <ins>Analyseren van de export</ins>
1. Login op de Tools machine
2. Open een elevated 'Windows PowerShell v5.1' window (zie boven voor instructies) en browse naar de folder waar de scripts naar toe gekopieerd zijn
3. Voer het volgende commando uit: `.\RunBIOAssessment.ps1`
4. Wanneer er geen fouten zijn opgetreden, zal er een Output folder zijn aangemaakt met daarin een folder met de datum van vandaag. Hierin zouden diverse files moeten zijn aangemaakt:
    1. Één CSV file
    2. Één PS1 file
    3. Één PSD1 file
    4. Drie JSON files

#### <ins>Updaten Power BI dashboard</ins>

1. Login op de Tools machine
2. Open een Windows Verkenner
3. Browse naar de folder waar je de scripts hebt gedownload
4. Dubbelklik op het bestand `M365-Bio Compliance.pbit`, dit opent de Power BI Desktop
5. Na openen wordt er gevraagd naar de locatie van de analyse files. Geef het volledige pad op van de locatie van de datum folder in Output folder van stap 4 uit de vorige sectie.
6. Klik op de knop **Load** om de analyze bestanden in te laden en de resultaten te bekijken.

![alt text](./media/dashboard.png?raw=true "Example of Power BI Dashboard")

Door een categorie te selecteren en op de knop **Bekijk details** te klikken (hou tijdens de klik de Ctrl toets ingedrukt), ga je naar een detail overzicht van de betreffende categorie.

Om de analyze resultaten opnieuw in te lezen, klik op de **Home** ribbon op de **Refresh** knop.

## Achtergrond informatie

Tijdens de analyze worden alle geëxporteerde componenten vergeleken met de BIO. Dit betekent dat het mogelijk is dat er false positives worden gerapporteerd. Wanneer  een set aan instellingen b.v. over meerdere policies verdeeld zijn en gebruikers  een combinatie van deze policies toegewezen krijgen, is het eindresultaat vanuit gebruikersperspectief compliant maar het resultaat van de individuele policies niet. Dit laatste wordt weergegeven in de rapportage.

### Voorbeeld
Policy1 zet Setting1, Policy2 zet Setting2 en Policy3 zet Setting3. In het toepassen van de policies krijgen alle users Policy1, maar de helft van de users Policy2 en de andere helft Policy3.

De BIO beschrijft dat Setting1 altijd ingesteld moet worden. Dit is door het toepassen van de combinatie van policies het geval, echter puur kijkend naar de policies, hebben Policy2 en Policy3 natuurlijk niet Setting1 ingesteld en worden die dus aangegeven als non-compliant.

## Disclaimer

Deze template dient te worden gezien als hulpmiddel om BIO compliancy te bereiken. Onder geen enkele voorwaarde garandeert Microsoft dat deze template direct leidt tot een volledige BIO compliancy ten aanzien van resources in de Microsoft 365 omgeving.

## Handelsmerken

Dit project kan handelsmerken of logo's bevatten voor projecten, producten of diensten. Geautoriseerd gebruik van Microsoft handelsmerken of logo's zijn onderworpen aan en moeten de [Handelsmerk- en merkrichtlijnen van Microsoft](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general) volgen. Het gebruik van handelsmerken of logo's van Microsoft in gewijzigde versies van dit project mag geen verwarring veroorzaken of sponsoring door Microsoft impliceren. Elk gebruik van handelsmerken of logo's van derden is onderworpen aan het beleid van die derden.

## Bronnen

|Titel|Link|
|---|---|
| Baseline Informatiebeveiliging Overheid | https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/bio-en-ensia/baseline-informatiebeveiliging-overheid/ |
| BIO versie 1.04 | https://www.cip-overheid.nl/media/13kduqsi/bio-versie-104zv_def.pdf |
| Handreiking BIO v2.0 opmaat | https://bio-overheid.nl/category/producten?product=Handreiking_BIO2_0_opmaat
| BIO Thema-uitwerking Clouddiensten | https://www.cip-overheid.nl/productcategorieen-en-workshops/producten?product=Clouddiensten |
| CIS Controls v8 Mapping to ISO/IEC 27002:2022 | https://www.cisecurity.org/insights/white-papers/cis-controls-v8-mapping-to-iso-iec2-27002-2022 |
