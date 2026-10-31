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
    // Seam de test: página inicial vía NIMBUS_KCM_PAGE (solo harness nested).
    Q_PROPERTY(QString initialPage READ initialPage CONSTANT)
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

    QString initialPage() const;
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
    void helperStatusChanged();

private:
    void readConfig();
    void markDirty();
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
};
