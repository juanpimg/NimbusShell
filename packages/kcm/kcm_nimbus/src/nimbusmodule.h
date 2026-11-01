// F8-T02/T04/T05 — KCM Nimbus: páginas reales (Apariencia, Accesibilidad,
// Atajos). Un solo módulo con Aplicar/Restablecer para todo.
// Ruling F8-T01-API (vigente): KQuickConfigModule + KConfigGroup manual.
// Canales reales Plasma 6.8 (medidos): kdeglobals/kwinrc/kremarc/
// plasmashellrc/plasma-appletsrc/nimbusrc/kcminputrc/kaccessrc vía KConfig;
// Orca vía gsettings; atajos vía scripts/nimbus-keys --home; tema vía
// scripts/nimbus-theme con fallback a escritura directa + plasma-apply-*.
// Todo best-effort fuera de KConfig: nunca falla, expone helperStatus.
#pragma once

#include <KQuickConfigModule>

class QProcess;

class NimbusModule : public KQuickConfigModule
{
    Q_OBJECT
    // F8-T01/T02 — Apariencia.
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(QString wallpaperPath READ wallpaperPath WRITE setWallpaperPath NOTIFY wallpaperPathChanged)
    Q_PROPERTY(int dockIconSize READ dockIconSize WRITE setDockIconSize NOTIFY dockIconSizeChanged)
    Q_PROPERTY(double dockZoomFactor READ dockZoomFactor WRITE setDockZoomFactor NOTIFY dockZoomFactorChanged)
    Q_PROPERTY(bool dockAutohide READ dockAutohide WRITE setDockAutohide NOTIFY dockAutohideChanged)
    Q_PROPERTY(int barHeight READ barHeight WRITE setBarHeight NOTIFY barHeightChanged)
    Q_PROPERTY(int animationSpeed READ animationSpeed WRITE setAnimationSpeed NOTIFY animationSpeedChanged)
    // F8-T05 — Accesibilidad.
    Q_PROPERTY(bool zoomEnabled READ zoomEnabled WRITE setZoomEnabled NOTIFY zoomEnabledChanged)
    Q_PROPERTY(bool invertColors READ invertColors WRITE setInvertColors NOTIFY invertColorsChanged)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY reduceMotionChanged)
    Q_PROPERTY(bool reduceTransparency READ reduceTransparency WRITE setReduceTransparency NOTIFY reduceTransparencyChanged)
    Q_PROPERTY(bool keyboardRepeat READ keyboardRepeat WRITE setKeyboardRepeat NOTIFY keyboardRepeatChanged)
    Q_PROPERTY(int repeatDelay READ repeatDelay WRITE setRepeatDelay NOTIFY repeatDelayChanged)
    Q_PROPERTY(int repeatRate READ repeatRate WRITE setRepeatRate NOTIFY repeatRateChanged)
    Q_PROPERTY(bool screenReader READ screenReader WRITE setScreenReader NOTIFY screenReaderChanged)
    Q_PROPERTY(bool orcaInstalled READ orcaInstalled CONSTANT)
    // F8-T04 — Atajos.
    Q_PROPERTY(bool cmdMode READ cmdMode WRITE setCmdMode NOTIFY cmdModeChanged)
    // F8-T03 — Red (estado en vivo; los cambios aplican al momento).
    Q_PROPERTY(bool wifiAvailable READ wifiAvailable CONSTANT)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY wifiSsidChanged)
    Q_PROPERTY(QStringList wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)
    Q_PROPERTY(bool wifiScanning READ wifiScanning NOTIFY wifiScanningChanged)
    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable CONSTANT)
    Q_PROPERTY(bool bluetoothPowered READ bluetoothPowered WRITE setBluetoothPowered NOTIFY bluetoothPoweredChanged)
    Q_PROPERTY(QStringList bluetoothDevices READ bluetoothDevices NOTIFY bluetoothDevicesChanged)
    Q_PROPERTY(bool bluetoothScanning READ bluetoothScanning NOTIFY bluetoothScanningChanged)
    Q_PROPERTY(bool printingAvailable READ printingAvailable CONSTANT)
    Q_PROPERTY(QString printerInfo READ printerInfo NOTIFY printerInfoChanged)
    Q_PROPERTY(QStringList printerNames READ printerNames NOTIFY printerInfoChanged)
    // F8-T06 — Sistema (lecturas en vivo; NTP/energía aplican al momento).
    Q_PROPERTY(QStringList userList READ userList NOTIFY userListChanged)
    Q_PROPERTY(QString currentUser READ currentUser CONSTANT)
    Q_PROPERTY(QString hostName READ hostName NOTIFY hostNameChanged)
    Q_PROPERTY(QString timeZone READ timeZone NOTIFY timeZoneChanged)
    Q_PROPERTY(bool ntpEnabled READ ntpEnabled WRITE setNtpEnabled NOTIFY ntpEnabledChanged)
    Q_PROPERTY(QString systemLocale READ systemLocale NOTIFY systemLocaleChanged)
    Q_PROPERTY(QString energyProfile READ energyProfile WRITE setEnergyProfile NOTIFY energyProfileChanged)
    Q_PROPERTY(QStringList energyProfiles READ energyProfiles CONSTANT)
    // F8-T07 — Updates (checkupdates sin root; async).
    Q_PROPERTY(bool updatesAvailable READ updatesAvailable CONSTANT)
    Q_PROPERTY(int updatesCount READ updatesCount NOTIFY updatesCountChanged)
    Q_PROPERTY(QStringList updatesList READ updatesList NOTIFY updatesListChanged)
    Q_PROPERTY(bool updatesChecking READ updatesChecking NOTIFY updatesCheckingChanged)
    Q_PROPERTY(bool dailyCheck READ dailyCheck WRITE setDailyCheck NOTIFY dailyCheckChanged)
    Q_PROPERTY(bool discoverInstalled READ discoverInstalled CONSTANT)
    Q_PROPERTY(bool snapshotsAvailable READ snapshotsAvailable NOTIFY snapshotsAvailableChanged)
    // Review F8-T03/T06/T07: acciones con confirmación y salida visible.
    Q_PROPERTY(bool installingUpdate READ installingUpdate NOTIFY installingUpdateChanged)
    Q_PROPERTY(QString installingPackage READ installingPackage NOTIFY installingPackageChanged)
    Q_PROPERTY(QString installOutput READ installOutput NOTIFY installOutputChanged)
    // Seam de test: página inicial vía NIMBUS_KCM_PAGE (solo harness nested).
    Q_PROPERTY(QString initialPage READ initialPage CONSTANT)
    // Seam de test: auto-comprobar updates al abrir (NIMBUS_KCM_AUTOCHECK).
    Q_PROPERTY(bool autoCheckUpdates READ autoCheckUpdates CONSTANT)
    Q_PROPERTY(QString helperStatus READ helperStatus WRITE setHelperStatus NOTIFY helperStatusChanged)

public:
    explicit NimbusModule(QObject *parent, const KPluginMetaData &metaData);

    bool darkMode() const;
    void setDarkMode(bool dark);
    QString accentColor() const;
    void setAccentColor(const QString &color);
    QString wallpaperPath() const;
    void setWallpaperPath(const QString &path);
    int dockIconSize() const;
    void setDockIconSize(int px);
    double dockZoomFactor() const;
    void setDockZoomFactor(double factor);
    bool dockAutohide() const;
    void setDockAutohide(bool hide);
    int barHeight() const;
    void setBarHeight(int px);
    int animationSpeed() const;
    void setAnimationSpeed(int speed);

    bool zoomEnabled() const;
    void setZoomEnabled(bool on);
    bool invertColors() const;
    void setInvertColors(bool on);
    bool reduceMotion() const;
    void setReduceMotion(bool on);
    bool reduceTransparency() const;
    void setReduceTransparency(bool on);
    bool keyboardRepeat() const;
    void setKeyboardRepeat(bool on);
    int repeatDelay() const;
    void setRepeatDelay(int ms);
    int repeatRate() const;
    void setRepeatRate(int perSecond);
    bool screenReader() const;
    void setScreenReader(bool on);
    bool orcaInstalled() const;

    bool cmdMode() const;
    void setCmdMode(bool meta);

    // F8-T03.
    bool wifiAvailable() const;
    bool wifiEnabled() const;
    void setWifiEnabled(bool on);
    QString wifiSsid() const;
    QStringList wifiNetworks() const;
    bool wifiScanning() const;
    bool bluetoothAvailable() const;
    bool bluetoothPowered() const;
    void setBluetoothPowered(bool on);
    QStringList bluetoothDevices() const;
    bool bluetoothScanning() const;
    bool printingAvailable() const;
    QString printerInfo() const;
    QStringList printerNames() const;
    Q_INVOKABLE void refreshWifi();
    Q_INVOKABLE bool connectWifi(const QString &ssid, const QString &password);
    Q_INVOKABLE void refreshBluetooth();
    // Review: vincular/conectar/desconectar (bluetoothctl, sin root).
    Q_INVOKABLE bool pairBluetooth(const QString &mac);
    Q_INVOKABLE bool connectBluetooth(const QString &mac);
    Q_INVOKABLE bool disconnectBluetooth(const QString &mac);
    Q_INVOKABLE void scanBluetooth();
    Q_INVOKABLE bool printTestPage(const QString &printer);
    // F8-T06.
    QStringList userList() const;
    QString currentUser() const;
    QString hostName() const;
    QString timeZone() const;
    bool ntpEnabled() const;
    void setNtpEnabled(bool on);
    QString systemLocale() const;
    QString energyProfile() const;
    void setEnergyProfile(const QString &profile);
    QStringList energyProfiles() const;
    Q_INVOKABLE void refreshSystem();
    // F8-T07.
    bool updatesAvailable() const;
    int updatesCount() const;
    QStringList updatesList() const;
    bool updatesChecking() const;
    bool installingUpdate() const;
    QString installingPackage() const;
    QString installOutput() const;
    bool dailyCheck() const;
    void setDailyCheck(bool on);
    bool discoverInstalled() const;
    bool snapshotsAvailable() const;
    Q_INVOKABLE void refreshUpdates();
    // Review: instalar un paquete con confirmación previa en QML.
    Q_INVOKABLE void installUpdate(const QString &package);
    // Review: hostname/locale intentan polkit; sin permiso solo avisan.
    Q_INVOKABLE bool trySetHostName(const QString &name);
    Q_INVOKABLE bool trySetLocale(const QString &locale);
    // F8-T08 — Reset canónico por sección (backup + defaults + escritura).
    Q_INVOKABLE void resetSection(const QString &section);

    QString initialPage() const;
    bool autoCheckUpdates() const;
    QString helperStatus() const;
    void setHelperStatus(const QString &status);

    // Salto a KCMs existentes (embeber por salto, F8-kcm.md §2): nunca crashea
    // si el destino no está instalado; devuelve false en ese caso.
    Q_INVOKABLE bool openKcm(const QString &kcmId);
    // Lanza una app por binario (p. ej. Discover). Best-effort, nunca falla.
    Q_INVOKABLE bool openApp(const QString &binary);
    // Lanza scripts/nimbus-theme si está en PATH (best-effort, nunca falla).
    Q_INVOKABLE void applySystemTheme();

public Q_SLOTS:
    void load() override;
    void save() override;
    void defaults() override;

Q_SIGNALS:
    void darkModeChanged();
    void accentColorChanged();
    void wallpaperPathChanged();
    void dockIconSizeChanged();
    void dockZoomFactorChanged();
    void dockAutohideChanged();
    void barHeightChanged();
    void animationSpeedChanged();
    void zoomEnabledChanged();
    void invertColorsChanged();
    void reduceMotionChanged();
    void reduceTransparencyChanged();
    void keyboardRepeatChanged();
    void repeatDelayChanged();
    void repeatRateChanged();
    void screenReaderChanged();
    void cmdModeChanged();
    void wifiEnabledChanged();
    void wifiSsidChanged();
    void wifiNetworksChanged();
    void wifiScanningChanged();
    void bluetoothPoweredChanged();
    void bluetoothDevicesChanged();
    void bluetoothScanningChanged();
    void printerInfoChanged();
    void userListChanged();
    void hostNameChanged();
    void timeZoneChanged();
    void ntpEnabledChanged();
    void systemLocaleChanged();
    void energyProfileChanged();
    void updatesCountChanged();
    void updatesListChanged();
    void updatesCheckingChanged();
    void installingUpdateChanged();
    void installingPackageChanged();
    void installOutputChanged();
    void installFinished(bool ok);
    void dailyCheckChanged();
    void snapshotsAvailableChanged();
    void updatesFinished();
    void helperStatusChanged();

private:
    void readConfig();
    void markDirty();
    // F8-T08: copia los ficheros que toca a ~/.config/nimbusshell-backup-*.
    // Solo crea directorios nuevos; jamás borra backups ajenos.
    QString backupConfigs();
    void setCanonical(const QString &section);
    void saveAppearance(QStringList &notes);
    void saveAccessibility(QStringList &notes);
    void saveShortcuts(QStringList &notes);
    void saveSystem(QStringList &notes);
    void saveUpdates(QStringList &notes);
    bool runHelper(const QString &program, const QStringList &args, int timeoutMs = 15000);
    QString gsettingsGet(const QString &schema, const QString &key);
    bool gsettingsSet(const QString &schema, const QString &key, const QString &value);

    bool m_darkMode = true;
    QString m_accentColor = QStringLiteral("#0A84FF");
    QString m_wallpaperPath;
    int m_dockIconSize = 48;
    double m_dockZoomFactor = 1.6;
    bool m_dockAutohide = false;
    int m_barHeight = 24;
    int m_animationSpeed = 3;

    bool m_zoomEnabled = false;
    bool m_invertColors = false;
    bool m_reduceMotion = false;
    bool m_reduceTransparency = false;
    bool m_keyboardRepeat = true;
    int m_repeatDelay = 500;
    int m_repeatRate = 25;
    bool m_screenReader = false;
    bool m_orcaInstalled = false;

    bool m_cmdMode = true;
    QString m_initialPage;
    QString m_helperStatus;
    bool m_loaded = false;

    // F8-T03 — estado en vivo.
    bool m_nmcliAvailable = false;
    bool m_wifiEnabled = false;
    QString m_wifiSsid;
    QStringList m_wifiNetworks;
    bool m_wifiScanning = false;
    bool m_bluetoothAvailable = false;
    bool m_bluetoothPowered = false;
    QStringList m_bluetoothDevices;
    bool m_bluetoothScanning = false;
    bool m_printingAvailable = false;
    QString m_printerInfo;
    // F8-T06 — estado en vivo.
    QStringList m_userList;
    QString m_currentUser;
    QString m_hostName;
    QString m_timeZone;
    bool m_ntpEnabled = false;
    QString m_systemLocale;
    QString m_energyProfile;
    QStringList m_energyProfiles;
    // F8-T07 — estado en vivo.
    bool m_checkupdatesAvailable = false;
    int m_updatesCount = -1;
    QStringList m_updatesList;
    QProcess *m_updatesProc = nullptr;
    QProcess *m_installProc = nullptr;
    QString m_installingPackage;
    QString m_installOutput;
    bool m_dailyCheck = false;
    bool m_discoverInstalled = false;
    bool m_snapshotsAvailable = false;
    bool m_autoCheckUpdates = false;
};
