// F8-T02/T04/T05 — implementación. Canales (medidos en Plasma 6.8.2):
// kdeglobals [General] ColorScheme + [KDE] LookAndFeelPackage;
// nimbusrc [Appearance] Wallpaper (claves propias); kremarc [General]
// IconSize/MaxZoomFactor/VisibilityMode (0 visible, 1 autohide);
// plasmashellrc [PlasmaViews][Panel *][Defaults] thickness (todos los
// paneles); kwinrc [Compositing] AnimationSpeed + [Plugins] zoomEnabled,
// invertEnabled, blurEnabled; kcminputrc [Keyboard] KeyboardRepeating,
// RepeatDelay, RepeatRate; kaccessrc [ScreenReader] + gsettings Orca;
// kglobalshortcutsrc (vía scripts/nimbus-keys --home). Sin KAuth (F8-T06),
// sin root, sin hilos. Todo lo externo es best-effort con helperStatus.
#include "nimbusmodule.h"

#include <KConfigGroup>
#include <KPluginFactory>
#include <KSharedConfig>
#include <QDir>
#include <QProcess>
#include <QStandardPaths>

K_PLUGIN_CLASS_WITH_JSON(NimbusModule, "metadata.json")

namespace
{
constexpr char kColorSchemeKey[] = "ColorScheme";
constexpr char kLookAndFeelKey[] = "LookAndFeelPackage";
constexpr char kLightScheme[] = "BreezeLight";
constexpr char kDarkScheme[] = "BreezeDark";
constexpr char kLightLook[] = "org.kde.breeze.desktop";
constexpr char kDarkLook[] = "org.kde.breezedark.desktop";
// Contrato Tahoe §2.1: acento #007AFF (light) / #0A84FF (dark) [HIG].
constexpr char kLightAccent[] = "#007AFF";
constexpr char kDarkAccent[] = "#0A84FF";

constexpr int kDockIconMin = 24;
constexpr int kDockIconMax = 96;
constexpr int kDockIconDefault = 48;
constexpr double kZoomMin = 1.0;
constexpr double kZoomMax = 2.0;
constexpr double kZoomDefault = 1.6;
constexpr int kBarMin = 16;
constexpr int kBarMax = 64;
constexpr int kBarDefault = 24;
constexpr int kAnimMin = 0;
constexpr int kAnimMax = 3;
constexpr int kAnimDefault = 3;
constexpr int kDelayMin = 100;
constexpr int kDelayMax = 1000;
constexpr int kDelayDefault = 500;
constexpr int kRateMin = 5;
constexpr int kRateMax = 50;
constexpr int kRateDefault = 25;
}

NimbusModule::NimbusModule(QObject *parent, const KPluginMetaData &metaData)
    : KQuickConfigModule(parent, metaData)
    , m_orcaInstalled(!QStandardPaths::findExecutable(QStringLiteral("orca")).isEmpty())
{
    setButtons(Apply | Default);
    const QString page = QString::fromLocal8Bit(qgetenv("NIMBUS_KCM_PAGE")).trimmed().toLower();
    // Seam solo-harness: ids válidos de docs/plans/research/F8-kcm.md.
    static const QStringList valid{
        QStringLiteral("appearance"), QStringLiteral("network"), QStringLiteral("shortcuts"),
        QStringLiteral("accessibility"), QStringLiteral("system"), QStringLiteral("updates"),
    };
    m_initialPage = valid.contains(page) ? page : QStringLiteral("appearance");
}

void NimbusModule::markDirty()
{
    if (m_loaded) {
        setNeedsSave(true);
    }
}

bool NimbusModule::runHelper(const QString &program, const QStringList &args, int timeoutMs)
{
    const QString exe = QStandardPaths::findExecutable(program);
    if (exe.isEmpty()) {
        return false;
    }
    // startDetached para procesos interactivos; execute+timeout para setters.
    if (timeoutMs <= 0) {
        return QProcess::startDetached(exe, args);
    }
    QProcess proc;
    proc.setProgram(exe);
    proc.setArguments(args);
    proc.start();
    if (!proc.waitForFinished(timeoutMs)) {
        proc.kill();
        return false;
    }
    return proc.exitCode() == 0;
}

QString NimbusModule::gsettingsGet(const QString &schema, const QString &key)
{
    const QString exe = QStandardPaths::findExecutable(QStringLiteral("gsettings"));
    if (exe.isEmpty()) {
        return {};
    }
    QProcess proc;
    proc.setProgram(exe);
    proc.setArguments({QStringLiteral("get"), schema, key});
    proc.start();
    if (!proc.waitForFinished(5000) || proc.exitCode() != 0) {
        return {};
    }
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}

bool NimbusModule::gsettingsSet(const QString &schema, const QString &key, const QString &value)
{
    return runHelper(QStringLiteral("gsettings"), {QStringLiteral("set"), schema, key, value});
}

void NimbusModule::setHelperStatus(const QString &status)
{
    if (m_helperStatus == status) {
        return;
    }
    m_helperStatus = status;
    Q_EMIT helperStatusChanged();
}

// --- Apariencia ---

bool NimbusModule::darkMode() const
{
    return m_darkMode;
}

void NimbusModule::setDarkMode(bool dark)
{
    if (m_darkMode == dark) {
        return;
    }
    m_darkMode = dark;
    // Acento canónico del modo si el usuario no fijó uno propio.
    m_accentColor = dark ? QString::fromLatin1(kDarkAccent) : QString::fromLatin1(kLightAccent);
    Q_EMIT darkModeChanged();
    Q_EMIT accentColorChanged();
    markDirty();
}

QString NimbusModule::accentColor() const
{
    return m_accentColor;
}

void NimbusModule::setAccentColor(const QString &color)
{
    if (color.isEmpty() || m_accentColor == color) {
        return;
    }
    m_accentColor = color;
    Q_EMIT accentColorChanged();
    markDirty();
}

QString NimbusModule::wallpaperPath() const
{
    return m_wallpaperPath;
}

void NimbusModule::setWallpaperPath(const QString &path)
{
    if (m_wallpaperPath == path) {
        return;
    }
    m_wallpaperPath = path;
    Q_EMIT wallpaperPathChanged();
    markDirty();
}

int NimbusModule::dockIconSize() const
{
    return m_dockIconSize;
}

void NimbusModule::setDockIconSize(int px)
{
    const int clamped = qBound(kDockIconMin, px, kDockIconMax);
    if (m_dockIconSize == clamped) {
        return;
    }
    m_dockIconSize = clamped;
    Q_EMIT dockIconSizeChanged();
    markDirty();
}

double NimbusModule::dockZoomFactor() const
{
    return m_dockZoomFactor;
}

void NimbusModule::setDockZoomFactor(double factor)
{
    const double clamped = qBound(kZoomMin, factor, kZoomMax);
    if (qFuzzyCompare(m_dockZoomFactor, clamped)) {
        return;
    }
    m_dockZoomFactor = clamped;
    Q_EMIT dockZoomFactorChanged();
    markDirty();
}

bool NimbusModule::dockAutohide() const
{
    return m_dockAutohide;
}

void NimbusModule::setDockAutohide(bool hide)
{
    if (m_dockAutohide == hide) {
        return;
    }
    m_dockAutohide = hide;
    Q_EMIT dockAutohideChanged();
    markDirty();
}

int NimbusModule::barHeight() const
{
    return m_barHeight;
}

void NimbusModule::setBarHeight(int px)
{
    const int clamped = qBound(kBarMin, px, kBarMax);
    if (m_barHeight == clamped) {
        return;
    }
    m_barHeight = clamped;
    Q_EMIT barHeightChanged();
    markDirty();
}

int NimbusModule::animationSpeed() const
{
    return m_animationSpeed;
}

void NimbusModule::setAnimationSpeed(int speed)
{
    const int clamped = qBound(kAnimMin, speed, kAnimMax);
    if (m_animationSpeed == clamped) {
        return;
    }
    m_animationSpeed = clamped;
    Q_EMIT animationSpeedChanged();
    // Coherencia con el toggle: velocidad 0 == movimiento reducido.
    if ((m_animationSpeed == 0) != m_reduceMotion) {
        m_reduceMotion = (m_animationSpeed == 0);
        Q_EMIT reduceMotionChanged();
    }
    markDirty();
}

// --- Accesibilidad ---

bool NimbusModule::zoomEnabled() const
{
    return m_zoomEnabled;
}

void NimbusModule::setZoomEnabled(bool on)
{
    if (m_zoomEnabled == on) {
        return;
    }
    m_zoomEnabled = on;
    Q_EMIT zoomEnabledChanged();
    markDirty();
}

bool NimbusModule::invertColors() const
{
    return m_invertColors;
}

void NimbusModule::setInvertColors(bool on)
{
    if (m_invertColors == on) {
        return;
    }
    m_invertColors = on;
    Q_EMIT invertColorsChanged();
    markDirty();
}

bool NimbusModule::reduceMotion() const
{
    return m_reduceMotion;
}

void NimbusModule::setReduceMotion(bool on)
{
    if (m_reduceMotion == on) {
        return;
    }
    m_reduceMotion = on;
    Q_EMIT reduceMotionChanged();
    // El canal real es AnimationSpeed=0 (instantáneo).
    if (on && m_animationSpeed != 0) {
        m_animationSpeed = 0;
        Q_EMIT animationSpeedChanged();
    } else if (!on && m_animationSpeed == 0) {
        m_animationSpeed = kAnimDefault;
        Q_EMIT animationSpeedChanged();
    }
    markDirty();
}

bool NimbusModule::reduceTransparency() const
{
    return m_reduceTransparency;
}

void NimbusModule::setReduceTransparency(bool on)
{
    if (m_reduceTransparency == on) {
        return;
    }
    m_reduceTransparency = on;
    Q_EMIT reduceTransparencyChanged();
    markDirty();
}

bool NimbusModule::keyboardRepeat() const
{
    return m_keyboardRepeat;
}

void NimbusModule::setKeyboardRepeat(bool on)
{
    if (m_keyboardRepeat == on) {
        return;
    }
    m_keyboardRepeat = on;
    Q_EMIT keyboardRepeatChanged();
    markDirty();
}

int NimbusModule::repeatDelay() const
{
    return m_repeatDelay;
}

void NimbusModule::setRepeatDelay(int ms)
{
    const int clamped = qBound(kDelayMin, ms, kDelayMax);
    if (m_repeatDelay == clamped) {
        return;
    }
    m_repeatDelay = clamped;
    Q_EMIT repeatDelayChanged();
    markDirty();
}

int NimbusModule::repeatRate() const
{
    return m_repeatRate;
}

void NimbusModule::setRepeatRate(int perSecond)
{
    const int clamped = qBound(kRateMin, perSecond, kRateMax);
    if (m_repeatRate == clamped) {
        return;
    }
    m_repeatRate = clamped;
    Q_EMIT repeatRateChanged();
    markDirty();
}

bool NimbusModule::screenReader() const
{
    return m_screenReader;
}

void NimbusModule::setScreenReader(bool on)
{
    if (m_screenReader == on) {
        return;
    }
    m_screenReader = on;
    Q_EMIT screenReaderChanged();
    markDirty();
}

bool NimbusModule::orcaInstalled() const
{
    return m_orcaInstalled;
}

// --- Atajos ---

bool NimbusModule::cmdMode() const
{
    return m_cmdMode;
}

void NimbusModule::setCmdMode(bool meta)
{
    if (m_cmdMode == meta) {
        return;
    }
    m_cmdMode = meta;
    Q_EMIT cmdModeChanged();
    markDirty();
}

QString NimbusModule::initialPage() const
{
    return m_initialPage;
}

QString NimbusModule::helperStatus() const
{
    return m_helperStatus;
}

bool NimbusModule::openKcm(const QString &kcmId)
{
    if (kcmId.isEmpty()) {
        return false;
    }
    const QString shell = QStandardPaths::findExecutable(QStringLiteral("kcmshell6"));
    if (shell.isEmpty()) {
        return false;
    }
    return QProcess::startDetached(shell, {kcmId});
}

bool NimbusModule::openApp(const QString &binary)
{
    if (binary.isEmpty()) {
        return false;
    }
    const QString exe = QStandardPaths::findExecutable(binary);
    if (exe.isEmpty()) {
        return false;
    }
    return QProcess::startDetached(exe, {});
}

void NimbusModule::applySystemTheme()
{
    const QString helper = QStandardPaths::findExecutable(QStringLiteral("nimbus-theme"));
    if (helper.isEmpty()) {
        return;
    }
    QStringList args{ m_darkMode ? QStringLiteral("dark") : QStringLiteral("light"),
                      QStringLiteral("--accent"), m_accentColor };
    QProcess::startDetached(helper, args);
}

void NimbusModule::readConfig()
{
    const KSharedConfig::Ptr globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    const KConfigGroup general(globals, QStringLiteral("General"));
    const QString scheme = general.readEntry(kColorSchemeKey, QString::fromLatin1(kDarkScheme));
    m_darkMode = scheme.contains(QStringLiteral("Dark"), Qt::CaseInsensitive);
    m_accentColor = m_darkMode ? QString::fromLatin1(kDarkAccent) : QString::fromLatin1(kLightAccent);

    const KSharedConfig::Ptr nimbus = KSharedConfig::openConfig(QStringLiteral("nimbusrc"));
    m_wallpaperPath = KConfigGroup(nimbus, QStringLiteral("Appearance")).readEntry("Wallpaper", QString());

    const KConfigGroup dock(KSharedConfig::openConfig(QStringLiteral("kremarc")),
                            QStringLiteral("General"));
    m_dockIconSize = qBound(kDockIconMin, dock.readEntry("IconSize", kDockIconDefault), kDockIconMax);
    m_dockZoomFactor = qBound(kZoomMin, dock.readEntry("MaxZoomFactor", kZoomDefault), kZoomMax);
    m_dockAutohide = dock.readEntry("VisibilityMode", 0) == 1;

    // Altura de barra: primer panel encontrado (todos se igualan al guardar).
    m_barHeight = kBarDefault;
    const KSharedConfig::Ptr shell = KSharedConfig::openConfig(QStringLiteral("plasmashellrc"));
    const QStringList groups = shell->groupList();
    for (const QString &group : groups) {
        if (group.startsWith(QLatin1String("PlasmaViews][Panel"))) {
            const int height = KConfigGroup(shell, group).readEntry("thickness", -1);
            if (height > 0) {
                m_barHeight = qBound(kBarMin, height, kBarMax);
                break;
            }
        }
    }

    const KSharedConfig::Ptr kwin = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    const KConfigGroup compositing(kwin, QStringLiteral("Compositing"));
    m_animationSpeed = qBound(kAnimMin, compositing.readEntry("AnimationSpeed", kAnimDefault), kAnimMax);
    const KConfigGroup plugins(kwin, QStringLiteral("Plugins"));
    m_zoomEnabled = plugins.readEntry("zoomEnabled", false);
    m_invertColors = plugins.readEntry("invertEnabled", false);
    // blurEnabled ausente == blur activo (defecto KWin).
    m_reduceTransparency = !plugins.readEntry("blurEnabled", true);
    m_reduceMotion = (m_animationSpeed == 0);

    const KConfigGroup keyboard(KSharedConfig::openConfig(QStringLiteral("kcminputrc")),
                                QStringLiteral("Keyboard"));
    m_keyboardRepeat = keyboard.readEntry("KeyboardRepeating", true);
    m_repeatDelay = qBound(kDelayMin, keyboard.readEntry("RepeatDelay", kDelayDefault), kDelayMax);
    m_repeatRate = qBound(kRateMin, keyboard.readEntry("RepeatRate", kRateDefault), kRateMax);

    m_screenReader = gsettingsGet(QStringLiteral("org.gnome.desktop.a11y.applications"),
                                  QStringLiteral("screen-reader-enabled"))
                         == QStringLiteral("true");

    // Modo Cmd/Ctrl: heurística sobre el atajo real (Meta+Q == modo Cmd).
    m_cmdMode = true;
    const KConfigGroup shortcuts(KSharedConfig::openConfig(QStringLiteral("kglobalshortcutsrc")),
                                 QStringLiteral("kwin"));
    if (shortcuts.hasKey("Window Close")) {
        m_cmdMode = shortcuts.readEntry("Window Close", QString()).contains(QLatin1String("Meta"));
    }
}

void NimbusModule::load()
{
    readConfig();
    m_loaded = true;
    setNeedsSave(false);
    setRepresentsDefaults(m_darkMode && m_accentColor == QLatin1String(kDarkAccent));
    Q_EMIT darkModeChanged();
    Q_EMIT accentColorChanged();
    Q_EMIT wallpaperPathChanged();
    Q_EMIT dockIconSizeChanged();
    Q_EMIT dockZoomFactorChanged();
    Q_EMIT dockAutohideChanged();
    Q_EMIT barHeightChanged();
    Q_EMIT animationSpeedChanged();
    Q_EMIT zoomEnabledChanged();
    Q_EMIT invertColorsChanged();
    Q_EMIT reduceMotionChanged();
    Q_EMIT reduceTransparencyChanged();
    Q_EMIT keyboardRepeatChanged();
    Q_EMIT repeatDelayChanged();
    Q_EMIT repeatRateChanged();
    Q_EMIT screenReaderChanged();
    Q_EMIT cmdModeChanged();
}

void NimbusModule::save()
{
    QStringList notes;

    // Apariencia en kdeglobals (+ script si existe; si no, plasma-apply-*).
    KSharedConfig::Ptr globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    KConfigGroup general(globals, QStringLiteral("General"));
    general.writeEntry(kColorSchemeKey,
                       m_darkMode ? QString::fromLatin1(kDarkScheme) : QString::fromLatin1(kLightScheme));
    KConfigGroup kde(globals, QStringLiteral("KDE"));
    kde.writeEntry(kLookAndFeelKey,
                   m_darkMode ? QString::fromLatin1(kDarkLook) : QString::fromLatin1(kLightLook));
    globals->sync();

    const QString themeHelper = QStandardPaths::findExecutable(QStringLiteral("nimbus-theme"));
    if (!themeHelper.isEmpty()) {
        QStringList args{ m_darkMode ? QStringLiteral("dark") : QStringLiteral("light"),
                          QStringLiteral("--accent"), m_accentColor };
        if (!m_wallpaperPath.isEmpty()) {
            args << QStringLiteral("--wallpaper") << m_wallpaperPath;
        }
        if (!runHelper(QStringLiteral("nimbus-theme"), args)) {
            notes << QStringLiteral("nimbus-theme falló");
        }
    } else {
        // Fallback directo: acento vía plasma-apply-colorscheme.
        if (!runHelper(QStringLiteral("plasma-apply-colorscheme"),
                       {QStringLiteral("-a"), m_accentColor,
                        m_darkMode ? QString::fromLatin1(kDarkScheme)
                                   : QString::fromLatin1(kLightScheme)})) {
            notes << QStringLiteral("sin plasma-apply-colorscheme");
        }
    }
    if (!m_wallpaperPath.isEmpty()) {
        if (!runHelper(QStringLiteral("plasma-apply-wallpaperimage"), {m_wallpaperPath}, 0)
            && themeHelper.isEmpty()) {
            notes << QStringLiteral("fondo pendiente (sin plasmashell)");
        }
    }
    KConfigGroup(KSharedConfig::openConfig(QStringLiteral("nimbusrc")),
                 QStringLiteral("Appearance"))
        .writeEntry("Wallpaper", m_wallpaperPath);
    KSharedConfig::openConfig(QStringLiteral("nimbusrc"))->sync();

    // Dock Krema.
    KSharedConfig::Ptr krema = KSharedConfig::openConfig(QStringLiteral("kremarc"));
    KConfigGroup dock(krema, QStringLiteral("General"));
    dock.writeEntry("IconSize", m_dockIconSize);
    dock.writeEntry("MaxZoomFactor", m_dockZoomFactor);
    dock.writeEntry("VisibilityMode", m_dockAutohide ? 1 : 0);
    krema->sync();

    // Barra: igualar todos los paneles (aplica al reiniciar sesión).
    KSharedConfig::Ptr shell = KSharedConfig::openConfig(QStringLiteral("plasmashellrc"));
    bool anyPanel = false;
    for (const QString &group : shell->groupList()) {
        if (group.startsWith(QLatin1String("PlasmaViews][Panel"))) {
            KConfigGroup(shell, group).writeEntry("thickness", m_barHeight);
            anyPanel = true;
        }
    }
    if (!anyPanel) {
        notes << QStringLiteral("barra: sin paneles (aplica al iniciar Plasma)");
    }
    shell->sync();

    // KWin: animaciones + efectos.
    KSharedConfig::Ptr kwin = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    KConfigGroup(kwin, QStringLiteral("Compositing"))
        .writeEntry("AnimationSpeed", m_reduceMotion ? 0 : m_animationSpeed);
    KConfigGroup plugins(kwin, QStringLiteral("Plugins"));
    plugins.writeEntry("zoomEnabled", m_zoomEnabled);
    plugins.writeEntry("invertEnabled", m_invertColors);
    plugins.writeEntry("blurEnabled", !m_reduceTransparency);
    kwin->sync();
    if (!runHelper(QStringLiteral("qdbus6"),
                   {QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
                    QStringLiteral("reconfigure")})) {
        notes << QStringLiteral("KWin aplica al reiniciar sesión");
    }

    // Teclado.
    KSharedConfig::Ptr input = KSharedConfig::openConfig(QStringLiteral("kcminputrc"));
    KConfigGroup keyboard(input, QStringLiteral("Keyboard"));
    keyboard.writeEntry("KeyboardRepeating", m_keyboardRepeat);
    keyboard.writeEntry("RepeatDelay", m_repeatDelay);
    keyboard.writeEntry("RepeatRate", m_repeatRate);
    input->sync();

    // Lector de pantalla.
    if (!gsettingsSet(QStringLiteral("org.gnome.desktop.a11y.applications"),
                      QStringLiteral("screen-reader-enabled"),
                      m_screenReader ? QStringLiteral("true") : QStringLiteral("false"))) {
        notes << QStringLiteral("lector: sin gsettings");
    }
    KSharedConfig::Ptr access = KSharedConfig::openConfig(QStringLiteral("kaccessrc"));
    KConfigGroup(access, QStringLiteral("ScreenReader")).writeEntry("Enabled", m_screenReader);
    access->sync();
    if (m_orcaInstalled) {
        runHelper(QStringLiteral("systemctl"),
                  {QStringLiteral("--user"), m_screenReader ? QStringLiteral("start")
                                                            : QStringLiteral("stop"),
                   QStringLiteral("orca.service")});
    } else if (m_screenReader) {
        notes << QStringLiteral("Orca no está instalado");
    }

    // Atajos vía script canónico (escribe --home, idempotente).
    const QString keysHelper = QStandardPaths::findExecutable(QStringLiteral("nimbus-keys"));
    if (!keysHelper.isEmpty()) {
        if (!runHelper(QStringLiteral("nimbus-keys"),
                       {QStringLiteral("--apply"), QStringLiteral("--toggle-cmd"),
                        m_cmdMode ? QStringLiteral("meta") : QStringLiteral("ctrl"),
                        QStringLiteral("--home"), QDir::homePath()})) {
            notes << QStringLiteral("nimbus-keys falló");
        } else {
            notes << QStringLiteral("atajos: aplican al reiniciar sesión");
        }
    } else if (!m_cmdMode) {
        notes << QStringLiteral("sin nimbus-keys");
    }

    setHelperStatus(notes.isEmpty() ? QString() : notes.join(QStringLiteral(" · ")));
    setNeedsSave(false);
}

void NimbusModule::defaults()
{
    m_darkMode = true;
    m_accentColor = QString::fromLatin1(kDarkAccent);
    m_wallpaperPath.clear();
    m_dockIconSize = kDockIconDefault;
    m_dockZoomFactor = kZoomDefault;
    m_dockAutohide = false;
    m_barHeight = kBarDefault;
    m_animationSpeed = kAnimDefault;
    m_zoomEnabled = false;
    m_invertColors = false;
    m_reduceMotion = false;
    m_reduceTransparency = false;
    m_keyboardRepeat = true;
    m_repeatDelay = kDelayDefault;
    m_repeatRate = kRateDefault;
    m_screenReader = false;
    m_cmdMode = true;
    Q_EMIT darkModeChanged();
    Q_EMIT accentColorChanged();
    Q_EMIT wallpaperPathChanged();
    Q_EMIT dockIconSizeChanged();
    Q_EMIT dockZoomFactorChanged();
    Q_EMIT dockAutohideChanged();
    Q_EMIT barHeightChanged();
    Q_EMIT animationSpeedChanged();
    Q_EMIT zoomEnabledChanged();
    Q_EMIT invertColorsChanged();
    Q_EMIT reduceMotionChanged();
    Q_EMIT reduceTransparencyChanged();
    Q_EMIT keyboardRepeatChanged();
    Q_EMIT repeatDelayChanged();
    Q_EMIT repeatRateChanged();
    Q_EMIT screenReaderChanged();
    Q_EMIT cmdModeChanged();
    setNeedsSave(true);
    setRepresentsDefaults(true);
}

#include "nimbusmodule.moc"
