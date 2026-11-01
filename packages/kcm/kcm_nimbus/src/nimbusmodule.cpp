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
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QHostInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusInterface>
#include <QtDBus/QDBusReply>

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
} // namespace

namespace
{
// Ejecuta y captura stdout (vacío si falla). Solo lecturas rápidas.
QString runCapture(const QString &program, const QStringList &args, int timeoutMs = 10000)
{
    const QString exe = QStandardPaths::findExecutable(program);
    if (exe.isEmpty()) {
        return {};
    }
    QProcess proc;
    proc.setProgram(exe);
    proc.setArguments(args);
    proc.start();
    if (!proc.waitForFinished(timeoutMs) || proc.exitCode() != 0) {
        return {};
    }
    return QString::fromUtf8(proc.readAllStandardOutput());
}
}

NimbusModule::NimbusModule(QObject *parent, const KPluginMetaData &metaData)
    : KQuickConfigModule(parent, metaData)
    , m_orcaInstalled(!QStandardPaths::findExecutable(QStringLiteral("orca")).isEmpty())
{
    setButtons(Apply | Default);
    m_currentUser = QString::fromLocal8Bit(qgetenv("USER"));
    if (m_currentUser.isEmpty()) {
        m_currentUser = QString::fromLocal8Bit(qgetenv("LOGNAME"));
    }
    m_nmcliAvailable = !QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty();
    m_bluetoothAvailable = !QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty();
    m_printingAvailable = !QStandardPaths::findExecutable(QStringLiteral("lpstat")).isEmpty();
    m_checkupdatesAvailable =
        !QStandardPaths::findExecutable(QStringLiteral("checkupdates")).isEmpty();
    if (!m_checkupdatesAvailable) {
        m_checkupdatesAvailable =
            !QStandardPaths::findExecutable(QStringLiteral("pacman")).isEmpty();
    }
    m_discoverInstalled =
        !QStandardPaths::findExecutable(QStringLiteral("plasma-discover")).isEmpty();
    const QString page = QString::fromLocal8Bit(qgetenv("NIMBUS_KCM_PAGE")).trimmed().toLower();
    // Seam solo-harness: ids válidos de docs/plans/research/F8-kcm.md.
    static const QStringList valid{
        QStringLiteral("appearance"), QStringLiteral("network"), QStringLiteral("shortcuts"),
        QStringLiteral("accessibility"), QStringLiteral("system"), QStringLiteral("updates"),
    };
    m_initialPage = valid.contains(page) ? page : QStringLiteral("appearance");
    m_autoCheckUpdates = QString::fromLocal8Bit(qgetenv("NIMBUS_KCM_AUTOCHECK")) == QStringLiteral("1");
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

bool NimbusModule::autoCheckUpdates() const
{
    return m_autoCheckUpdates;
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
    // Estado en vivo (F8-T03/T06; T07 no auto-escanea: checkupdates tarda).
    refreshWifi();
    refreshBluetooth();
    if (!m_printingAvailable) {
        m_printerInfo = QString();
    } else {
        m_printerInfo =
            runCapture(QStringLiteral("lpstat"), {QStringLiteral("-p")}).trimmed();
    }
    refreshSystem();
    const QString timerPath =
        QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/systemd/user/nimbus-updates-check.timer");
    m_dailyCheck = QFile::exists(timerPath);
    if (QStandardPaths::findExecutable(QStringLiteral("snapper")).isEmpty()) {
        m_snapshotsAvailable = false;
    } else {
        m_snapshotsAvailable =
            !runCapture(QStringLiteral("snapper"), {QStringLiteral("list-configs")}).trimmed().isEmpty();
    }
    Q_EMIT screenReaderChanged();
    Q_EMIT cmdModeChanged();
    Q_EMIT printerInfoChanged();
    Q_EMIT dailyCheckChanged();
    Q_EMIT snapshotsAvailableChanged();
}

void NimbusModule::save()
{
    QStringList notes;
    backupConfigs();
    saveAppearance(notes);
    saveAccessibility(notes);
    saveShortcuts(notes);
    saveSystem(notes);
    saveUpdates(notes);
    setHelperStatus(notes.isEmpty() ? QString() : notes.join(QStringLiteral(" · ")));
    setNeedsSave(false);
}

QString NimbusModule::backupConfigs()
{
    const QString backupDir =
        QDir::homePath() + QStringLiteral("/.config/nimbusshell-backup-")
        + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-hhmmss"));
    static const char *files[] = {"kdeglobals", "kwinrc",      "kremarc",
                                  "plasmashellrc", "nimbusrc",  "kcminputrc",
                                  "kaccessrc",     "kscreenlockerrc", "kglobalshortcutsrc"};
    const QString configHome =
        QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    for (const char *file : files) {
        const QString src = configHome + QLatin1Char('/') + QString::fromLatin1(file);
        if (!QFile::exists(src)) {
            continue;
        }
        QDir().mkpath(backupDir);
        QFile::copy(src, backupDir + QLatin1Char('/') + QString::fromLatin1(file));
    }
    return backupDir;
}

void NimbusModule::saveAppearance(QStringList &notes)
{
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

    // Velocidad (0 == movimiento reducido, coherente con Accesibilidad).
    KSharedConfig::Ptr kwinAnim = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    KConfigGroup(kwinAnim, QStringLiteral("Compositing"))
        .writeEntry("AnimationSpeed", m_reduceMotion ? 0 : m_animationSpeed);
    kwinAnim->sync();
}

void NimbusModule::saveAccessibility(QStringList &notes)
{
    // KWin: efectos de accesibilidad + velocidad (0 == movimiento reducido;
    // también la escribe Apariencia: mismo valor, idempotente).
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
}

void NimbusModule::saveShortcuts(QStringList &notes)
{
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
}

void NimbusModule::saveUpdates(QStringList &notes)
{
    // F8-T07: programar comprobación diaria (timer de usuario, sin root).
    const QString sysDir =
        QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/systemd/user");
    const QString servicePath = sysDir + QStringLiteral("/nimbus-updates-check.service");
    const QString timerPath = sysDir + QStringLiteral("/nimbus-updates-check.timer");
    if (m_dailyCheck) {
        QDir().mkpath(sysDir);
        QFile service(servicePath);
        if (service.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            QTextStream out(&service);
            out << "[Unit]\nDescription=Nimbus: comprobar actualizaciones pendientes\n\n"
                   "[Service]\nType=oneshot\nExecStart="
                << QStandardPaths::findExecutable(QStringLiteral("checkupdates"),
                                                  {QStringLiteral("/usr/bin")})
                << "\n";
        }
        QFile timer(timerPath);
        if (timer.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            QTextStream out(&timer);
            out << "[Unit]\nDescription=Nimbus: comprobar actualizaciones a diario\n\n"
                   "[Timer]\nOnCalendar=daily\nPersistent=true\n\n"
                   "[Install]\nWantedBy=timers.target\n";
        }
        if (!runHelper(QStringLiteral("systemctl"),
                       {QStringLiteral("--user"), QStringLiteral("daemon-reload")})
            || !runHelper(QStringLiteral("systemctl"),
                          {QStringLiteral("--user"), QStringLiteral("enable"),
                           QStringLiteral("nimbus-updates-check.timer")})) {
            notes << QStringLiteral("temporizador guardado (actívalo con systemctl --user)");
        }
    } else {
        QFile::remove(servicePath);
        QFile::remove(timerPath);
    }
}

// --- F8-T03: Red en vivo (nmcli/bluetoothctl/lpstat, sin root) ---

bool NimbusModule::wifiAvailable() const
{
    return m_nmcliAvailable;
}

bool NimbusModule::wifiEnabled() const
{
    return m_wifiEnabled;
}

void NimbusModule::setWifiEnabled(bool on)
{
    if (!m_nmcliAvailable) {
        setHelperStatus(QStringLiteral("Sin wifi en este equipo."));
        return;
    }
    if (!runHelper(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"),
                                             on ? QStringLiteral("on") : QStringLiteral("off")})) {
        setHelperStatus(QStringLiteral("No se pudo cambiar el wifi (puede pedir permiso)."));
        return;
    }
    m_wifiEnabled = on;
    Q_EMIT wifiEnabledChanged();
    refreshWifi();
}

QString NimbusModule::wifiSsid() const
{
    return m_wifiSsid;
}

QStringList NimbusModule::wifiNetworks() const
{
    return m_wifiNetworks;
}

bool NimbusModule::wifiScanning() const
{
    return m_wifiScanning;
}

void NimbusModule::refreshWifi()
{
    if (!m_nmcliAvailable) {
        return;
    }
    m_wifiScanning = true;
    Q_EMIT wifiScanningChanged();
    m_wifiEnabled =
        runCapture(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi")})
            .trimmed()
        == QStringLiteral("enabled");
    Q_EMIT wifiEnabledChanged();
    // Activa primero (conectar exige escaneo reciente); lista terseada
    // ACTIVE,SSID,SIGNAL,SECURITY. Sin secretos en ningún fichero.
    runCapture(QStringLiteral("nmcli"), {QStringLiteral("device"), QStringLiteral("wifi"),
                                         QStringLiteral("rescan")}, 15000);
    const QString out =
        runCapture(QStringLiteral("nmcli"),
                   {QStringLiteral("-t"), QStringLiteral("-f"),
                    QStringLiteral("ACTIVE,SSID,SIGNAL,SECURITY"), QStringLiteral("device"),
                    QStringLiteral("wifi"), QStringLiteral("list")}, 20000);
    m_wifiNetworks.clear();
    m_wifiSsid.clear();
    const QStringList lines = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        // SSID puede llevar '\:' escapado: partir por ':' no escapados.
        QStringList fields;
        QString current;
        bool escape = false;
        for (const QChar ch : line) {
            if (escape) {
                current += ch;
                escape = false;
            } else if (ch == QLatin1Char('\\')) {
                escape = true;
            } else if (ch == QLatin1Char(':')) {
                fields << current;
                current.clear();
            } else {
                current += ch;
            }
        }
        fields << current;
        if (fields.size() < 4 || fields.at(1).isEmpty()) {
            continue;
        }
        const bool active = fields.at(0).trimmed().compare(QLatin1String("yes"),
                                                           Qt::CaseInsensitive)
            == 0;
        if (active) {
            m_wifiSsid = fields.at(1);
        }
        // Forma "ssid|señal|seguridad|activa" para el delegado QML.
        m_wifiNetworks
            << QStringLiteral("%1|%2|%3|%4")
                   .arg(fields.at(1), fields.at(2).trimmed(), fields.at(3).trimmed(),
                        active ? QStringLiteral("1") : QStringLiteral("0"));
    }
    Q_EMIT wifiSsidChanged();
    Q_EMIT wifiNetworksChanged();
    m_wifiScanning = false;
    Q_EMIT wifiScanningChanged();
}

bool NimbusModule::connectWifi(const QString &ssid, const QString &password)
{
    if (!m_nmcliAvailable || ssid.isEmpty()) {
        return false;
    }
    // La contraseña viaja solo en memoria al proceso nmcli; jamás se guarda.
    QStringList args{QStringLiteral("device"), QStringLiteral("wifi"),
                     QStringLiteral("connect"), ssid};
    if (!password.isEmpty()) {
        args << QStringLiteral("password") << password;
    }
    const bool ok = runHelper(QStringLiteral("nmcli"), args, 45000);
    setHelperStatus(ok ? QStringLiteral("Conectado a %1.").arg(ssid)
                       : QStringLiteral("No se pudo conectar a %1.").arg(ssid));
    if (ok) {
        refreshWifi();
    }
    return ok;
}

bool NimbusModule::bluetoothAvailable() const
{
    return m_bluetoothAvailable;
}

bool NimbusModule::bluetoothPowered() const
{
    return m_bluetoothPowered;
}

void NimbusModule::setBluetoothPowered(bool on)
{
    if (!m_bluetoothAvailable) {
        setHelperStatus(QStringLiteral("Sin Bluetooth en este equipo."));
        return;
    }
    if (!runHelper(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("power"), on ? QStringLiteral("on") : QStringLiteral("off")})) {
        setHelperStatus(QStringLiteral("No se pudo cambiar el Bluetooth."));
        return;
    }
    m_bluetoothPowered = on;
    Q_EMIT bluetoothPoweredChanged();
    refreshBluetooth();
}

QStringList NimbusModule::bluetoothDevices() const
{
    return m_bluetoothDevices;
}

void NimbusModule::refreshBluetooth()
{
    if (!m_bluetoothAvailable) {
        return;
    }
    const QString show =
        runCapture(QStringLiteral("bluetoothctl"), {QStringLiteral("show")});
    m_bluetoothPowered = show.contains(QStringLiteral("Powered: yes"));
    Q_EMIT bluetoothPoweredChanged();
    // Forma "nombre|mac|conectado|vinculado" (vincular pide agente).
    m_bluetoothDevices.clear();
    const QStringList lines =
        runCapture(QStringLiteral("bluetoothctl"), {QStringLiteral("devices")})
            .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        // "Device MAC Nombre con espacios"
        const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        if (parts.size() < 3 || parts.at(0) != QLatin1String("Device")) {
            continue;
        }
        const QString mac = parts.at(1);
        const QString name = parts.mid(2).join(QLatin1Char(' '));
        const QString info =
            runCapture(QStringLiteral("bluetoothctl"), {QStringLiteral("info"), mac});
        const bool connected = info.contains(QStringLiteral("Connected: yes"));
        m_bluetoothDevices << QStringLiteral("%1|%2|%3|1").arg(
            name, mac, connected ? QStringLiteral("1") : QStringLiteral("0"));
    }
    Q_EMIT bluetoothDevicesChanged();
}

bool NimbusModule::bluetoothScanning() const
{
    return m_bluetoothScanning;
}

namespace
{
bool validMac(const QString &mac)
{
    static const QRegularExpression re(QStringLiteral("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"));
    return re.match(mac).hasMatch();
}

// bluetoothctl informa con "…uccessful…" (Pairing/Connection successful,
// Successful disconnected); "Failed"/"not available" es error.
bool btOk(const QString &output)
{
    return output.contains(QStringLiteral("uccessful"), Qt::CaseInsensitive)
        && !output.contains(QStringLiteral("Failed"), Qt::CaseInsensitive);
}
}

bool NimbusModule::pairBluetooth(const QString &mac)
{
    if (!m_bluetoothAvailable || !validMac(mac)) {
        return false;
    }
    const QString out =
        runCapture(QStringLiteral("bluetoothctl"), {QStringLiteral("pair"), mac}, 30000);
    const bool ok = btOk(out);
    setHelperStatus(ok ? QStringLiteral("Vinculado con %1.").arg(mac)
                       : QStringLiteral("No se pudo vincular con %1.").arg(mac));
    if (ok) {
        refreshBluetooth();
    }
    Q_EMIT bluetoothDevicesChanged();
    return ok;
}

bool NimbusModule::connectBluetooth(const QString &mac)
{
    if (!m_bluetoothAvailable || !validMac(mac)) {
        return false;
    }
    const QString out =
        runCapture(QStringLiteral("bluetoothctl"), {QStringLiteral("connect"), mac}, 20000);
    const bool ok = btOk(out);
    setHelperStatus(ok ? QStringLiteral("Conectado a %1.").arg(mac)
                       : QStringLiteral("No se pudo conectar a %1.").arg(mac));
    if (ok) {
        refreshBluetooth();
    }
    Q_EMIT bluetoothDevicesChanged();
    return ok;
}

bool NimbusModule::disconnectBluetooth(const QString &mac)
{
    if (!m_bluetoothAvailable || !validMac(mac)) {
        return false;
    }
    const QString out =
        runCapture(QStringLiteral("bluetoothctl"), {QStringLiteral("disconnect"), mac}, 20000);
    const bool ok = btOk(out);
    setHelperStatus(ok ? QStringLiteral("Desconectado de %1.").arg(mac)
                       : QStringLiteral("No se pudo desconectar de %1.").arg(mac));
    if (ok) {
        refreshBluetooth();
    }
    Q_EMIT bluetoothDevicesChanged();
    return ok;
}

void NimbusModule::scanBluetooth()
{
    if (!m_bluetoothAvailable || m_bluetoothScanning) {
        return;
    }
    m_bluetoothScanning = true;
    Q_EMIT bluetoothScanningChanged();
    refreshBluetooth();
    // Descubrimiento breve (10 s); fusiona no vinculados como paired=0.
    QSet<QString> known;
    for (const QString &entry : m_bluetoothDevices) {
        known.insert(entry.split(QLatin1Char('|')).value(1));
    }
    const QStringList lines =
        runCapture(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("--timeout"), QStringLiteral("10"), QStringLiteral("scan"),
                    QStringLiteral("on")}, 15000)
            .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        // "[NEW] Device MAC Nombre…"
        const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        const int dev = parts.indexOf(QStringLiteral("Device"));
        if (dev < 0 || parts.size() < dev + 2 || !validMac(parts.at(dev + 1))) {
            continue;
        }
        const QString mac = parts.at(dev + 1);
        if (known.contains(mac)) {
            continue;
        }
        known.insert(mac);
        const QString name = parts.mid(dev + 2).join(QLatin1Char(' '));
        m_bluetoothDevices << QStringLiteral("%1|%2|0|0").arg(
            name.isEmpty() ? mac : name, mac);
    }
    Q_EMIT bluetoothDevicesChanged();
    m_bluetoothScanning = false;
    Q_EMIT bluetoothScanningChanged();
}

bool NimbusModule::printingAvailable() const
{
    return m_printingAvailable;
}

QString NimbusModule::printerInfo() const
{
    return m_printerInfo;
}

QStringList NimbusModule::printerNames() const
{
    // "printer Nombre ..." (una por línea en `lpstat -p`).
    QStringList names;
    const QStringList lines = m_printerInfo.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        if (parts.size() >= 2 && parts.at(0) == QLatin1String("printer")) {
            names << parts.at(1);
        }
    }
    return names;
}

bool NimbusModule::printTestPage(const QString &printer)
{
    if (!m_printingAvailable) {
        setHelperStatus(QStringLiteral("Sin soporte de impresión en este equipo (falta CUPS)."));
        return false;
    }
    if (printer.isEmpty()) {
        return false;
    }
    // Página temporal con texto propio (sin activos de terceros).
    const QString path =
        QDir::tempPath() + QStringLiteral("/nimbus-test-page-%1.txt").arg(QCoreApplication::applicationPid());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        setHelperStatus(QStringLiteral("No se pudo crear la página de prueba."));
        return false;
    }
    QTextStream out(&file);
    out << "Nimbus — página de prueba\nImpresora: " << printer << "\n";
    file.close();
    const bool ok = runHelper(QStringLiteral("lp"), {QStringLiteral("-d"), printer, path}, 30000);
    QFile::remove(path);
    setHelperStatus(ok ? QStringLiteral("Página enviada a %1.").arg(printer)
                       : QStringLiteral("No se pudo imprimir en %1.").arg(printer));
    return ok;
}

// --- F8-T06: Sistema en vivo ---

QStringList NimbusModule::userList() const
{
    return m_userList;
}

QString NimbusModule::currentUser() const
{
    return m_currentUser;
}

QString NimbusModule::hostName() const
{
    return m_hostName;
}

QString NimbusModule::timeZone() const
{
    return m_timeZone;
}

bool NimbusModule::ntpEnabled() const
{
    return m_ntpEnabled;
}

void NimbusModule::setNtpEnabled(bool on)
{
    // timedatectl set-ntp exige privilegios: lo intenta (en sesión real
    // pide autenticación) y cuenta lo que pasó.
    if (runHelper(QStringLiteral("timedatectl"),
                  {QStringLiteral("set-ntp"), on ? QStringLiteral("true")
                                                 : QStringLiteral("false")})) {
        m_ntpEnabled = on;
        Q_EMIT ntpEnabledChanged();
    } else {
        setHelperStatus(QStringLiteral("Cambiar NTP necesita permiso de administrador."));
    }
}

QString NimbusModule::systemLocale() const
{
    return m_systemLocale;
}

QString NimbusModule::energyProfile() const
{
    return m_energyProfile;
}

void NimbusModule::setEnergyProfile(const QString &profile)
{
    if (profile.isEmpty() || !m_energyProfiles.contains(profile)) {
        return;
    }
    if (!runHelper(QStringLiteral("powerprofilesctl"), {QStringLiteral("set"), profile})) {
        setHelperStatus(QStringLiteral("No se pudo cambiar el perfil de energía."));
        return;
    }
    m_energyProfile = profile;
    Q_EMIT energyProfileChanged();
}

QStringList NimbusModule::energyProfiles() const
{
    return m_energyProfiles;
}

void NimbusModule::refreshSystem()
{
    // Usuarios: AccountsService por D-Bus; sin él, /etc/passwd
    // (uid>=1000 con shell válida + root; jamás contraseñas).
    m_userList.clear();
    bool viaAccounts = false;
    QDBusInterface accounts(QStringLiteral("org.freedesktop.Accounts"),
                            QStringLiteral("/org/freedesktop/Accounts"),
                            QStringLiteral("org.freedesktop.Accounts"),
                            QDBusConnection::systemBus());
    if (accounts.isValid()) {
        QDBusReply<QList<QDBusObjectPath>> reply = accounts.call(QStringLiteral("ListCachedUsers"));
        if (reply.isValid()) {
            for (const QDBusObjectPath &path : reply.value()) {
                QDBusInterface user(QStringLiteral("org.freedesktop.Accounts"), path.path(),
                                    QStringLiteral("org.freedesktop.Accounts.User"),
                                    QDBusConnection::systemBus());
                if (!user.isValid()) {
                    continue;
                }
                const QString name = user.property("UserName").toString();
                const QString real = user.property("RealName").toString();
                if (name.isEmpty()) {
                    continue;
                }
                m_userList << QStringLiteral("%1|%2|%3").arg(
                    name, real, name == m_currentUser ? QStringLiteral("1") : QStringLiteral("0"));
            }
            viaAccounts = !m_userList.isEmpty();
        }
    }
    if (!viaAccounts) {
        QFile passwd(QStringLiteral("/etc/passwd"));
        if (passwd.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&passwd);
            while (!in.atEnd()) {
                const QStringList fields = in.readLine().split(QLatin1Char(':'));
                if (fields.size() < 7) {
                    continue;
                }
                const QString name = fields.at(0);
                const int uid = fields.at(2).toInt();
                const QString shell = fields.at(6);
                const bool loginOk = !shell.endsWith(QLatin1String("nologin"))
                    && !shell.endsWith(QLatin1String("false"));
                if ((uid >= 1000 && loginOk) || uid == 0) {
                    m_userList << QStringLiteral("%1|%2|%3").arg(
                        name, fields.at(4).split(QLatin1Char(',')).first(),
                        name == m_currentUser ? QStringLiteral("1") : QStringLiteral("0"));
                }
            }
        }
    }
    Q_EMIT userListChanged();

    m_hostName = QHostInfo::localHostName();
    Q_EMIT hostNameChanged();

    m_timeZone =
        runCapture(QStringLiteral("timedatectl"), {QStringLiteral("show"), QStringLiteral("-p"),
                                                   QStringLiteral("Timezone")})
            .trimmed()
            .remove(QStringLiteral("Timezone="));
    Q_EMIT timeZoneChanged();
    m_ntpEnabled =
        runCapture(QStringLiteral("timedatectl"), {QStringLiteral("show"), QStringLiteral("-p"),
                                                   QStringLiteral("NTP")})
            .trimmed()
            .endsWith(QLatin1String("yes"), Qt::CaseInsensitive);
    Q_EMIT ntpEnabledChanged();

    m_systemLocale =
        runCapture(QStringLiteral("localectl"), {QStringLiteral("status")})
            .split(QLatin1Char('\n'), Qt::SkipEmptyParts)
            .filter(QStringLiteral("System Locale"))
            .value(0)
            .trimmed();
    Q_EMIT systemLocaleChanged();

    m_energyProfiles.clear();
    const QStringList profilesOut =
        runCapture(QStringLiteral("powerprofilesctl"), {QStringLiteral("list")})
            .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (QString line : profilesOut) {
        line = line.trimmed();
        if (line.startsWith(QLatin1Char('*'))) {
            line = line.mid(1).trimmed();
        }
        if (line.endsWith(QLatin1Char(':'))) {
            line.chop(1);
        }
        if (line == QStringLiteral("balanced") || line == QStringLiteral("performance")
            || line == QStringLiteral("power-saver")) {
            m_energyProfiles << line;
            if (profilesOut.join(QLatin1Char('\n')).contains(QLatin1String("* ") + line + QLatin1Char(':'))) {
                m_energyProfile = line;
            }
        }
    }
    if (m_energyProfile.isEmpty() && !m_energyProfiles.isEmpty()) {
        m_energyProfile = runCapture(QStringLiteral("powerprofilesctl"),
                                     {QStringLiteral("get")})
                              .trimmed();
    }
    Q_EMIT energyProfileChanged();
}

// --- F8-T07: Updates sin root (checkupdates async) ---

bool NimbusModule::updatesAvailable() const
{
    return m_checkupdatesAvailable;
}

int NimbusModule::updatesCount() const
{
    return m_updatesCount;
}

QStringList NimbusModule::updatesList() const
{
    return m_updatesList;
}

bool NimbusModule::updatesChecking() const
{
    return m_updatesProc != nullptr;
}

bool NimbusModule::dailyCheck() const
{
    return m_dailyCheck;
}

void NimbusModule::setDailyCheck(bool on)
{
    if (m_dailyCheck == on) {
        return;
    }
    m_dailyCheck = on;
    Q_EMIT dailyCheckChanged();
    markDirty();
}

bool NimbusModule::discoverInstalled() const
{
    return m_discoverInstalled;
}

bool NimbusModule::snapshotsAvailable() const
{
    return m_snapshotsAvailable;
}

void NimbusModule::refreshUpdates()
{
    if (m_updatesProc != nullptr) {
        return;
    }
    QString program = QStandardPaths::findExecutable(QStringLiteral("checkupdates"));
    QStringList args;
    if (program.isEmpty()) {
        // Fallback: pacman -Qu (solo lectura del db de sincronización).
        program = QStandardPaths::findExecutable(QStringLiteral("pacman"));
        if (program.isEmpty()) {
            setHelperStatus(QStringLiteral("Sin gestor de paquetes en este equipo."));
            return;
        }
        args = {QStringLiteral("-Qu")};
    }
    m_updatesProc = new QProcess(this);
    connect(m_updatesProc, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus) {
                QStringList lines;
                if (m_updatesProc != nullptr) {
                    // checkupdates rc=2 == sin actualizaciones; pacman -Qu rc=0.
                    lines = QString::fromUtf8(m_updatesProc->readAllStandardOutput())
                                .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
                    m_updatesProc->deleteLater();
                    m_updatesProc = nullptr;
                }
                Q_UNUSED(exitCode);
                m_updatesCount = lines.size();
                m_updatesList = lines.mid(0, 15);
                Q_EMIT updatesCountChanged();
                Q_EMIT updatesListChanged();
                Q_EMIT updatesCheckingChanged();
                Q_EMIT updatesFinished();
            });
    m_updatesProc->setProgram(program);
    m_updatesProc->setArguments(args);
    m_updatesProc->start();
    Q_EMIT updatesCheckingChanged();
}

void NimbusModule::saveSystem(QStringList &notes)
{
    // Energía: reafirma el perfil vigente (el setter ya lo aplicó al momento).
    if (!m_energyProfiles.isEmpty() && !m_energyProfile.isEmpty()) {
        if (!runHelper(QStringLiteral("powerprofilesctl"),
                       {QStringLiteral("set"), m_energyProfile})) {
            notes << QStringLiteral("No se pudo reafirmar el perfil de energía.");
        }
    }
    // NTP y resto del sistema son inmediatos o de solo lectura.
}

void NimbusModule::setCanonical(const QString &section)
{
    if (section == QLatin1String("appearance")) {
        m_darkMode = true;
        m_accentColor = QString::fromLatin1(kDarkAccent);
        m_wallpaperPath.clear();
        m_dockIconSize = kDockIconDefault;
        m_dockZoomFactor = kZoomDefault;
        m_dockAutohide = false;
        m_barHeight = kBarDefault;
        m_animationSpeed = kAnimDefault;
        Q_EMIT darkModeChanged();
        Q_EMIT accentColorChanged();
        Q_EMIT wallpaperPathChanged();
        Q_EMIT dockIconSizeChanged();
        Q_EMIT dockZoomFactorChanged();
        Q_EMIT dockAutohideChanged();
        Q_EMIT barHeightChanged();
        Q_EMIT animationSpeedChanged();
    } else if (section == QLatin1String("accessibility")) {
        m_zoomEnabled = false;
        m_invertColors = false;
        m_reduceMotion = false;
        m_reduceTransparency = false;
        // setReduceMotion(true) pudo pisar el miembro: restaurar canónico.
        m_animationSpeed = kAnimDefault;
        m_keyboardRepeat = true;
        m_repeatDelay = kDelayDefault;
        m_repeatRate = kRateDefault;
        m_screenReader = false;
        Q_EMIT zoomEnabledChanged();
        Q_EMIT invertColorsChanged();
        Q_EMIT reduceMotionChanged();
        Q_EMIT reduceTransparencyChanged();
        Q_EMIT animationSpeedChanged();
        Q_EMIT keyboardRepeatChanged();
        Q_EMIT repeatDelayChanged();
        Q_EMIT repeatRateChanged();
        Q_EMIT screenReaderChanged();
    } else if (section == QLatin1String("shortcuts")) {
        m_cmdMode = true;
        Q_EMIT cmdModeChanged();
    } else if (section == QLatin1String("system")) {
        if (!m_energyProfiles.isEmpty()) {
            m_energyProfile = m_energyProfiles.contains(QStringLiteral("balanced"))
                ? QStringLiteral("balanced")
                : m_energyProfiles.first();
        }
        m_ntpEnabled = true;
        Q_EMIT energyProfileChanged();
        Q_EMIT ntpEnabledChanged();
    } else if (section == QLatin1String("updates")) {
        m_dailyCheck = false;
        Q_EMIT dailyCheckChanged();
    }
}

void NimbusModule::resetSection(const QString &section)
{
    backupConfigs();
    QStringList notes;
    setCanonical(section);
    if (section == QLatin1String("appearance")) {
        saveAppearance(notes);
    } else if (section == QLatin1String("accessibility")) {
        // Pantalla de bloqueo canónica Nimbus (dotfiles kscreenlockerrc).
        KSharedConfig::Ptr lock = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
        KConfigGroup daemon(lock, QStringLiteral("Daemon"));
        daemon.writeEntry("Autolock", false);
        daemon.writeEntry("LockOnResume", false);
        daemon.writeEntry("LockOnStart", false);
        daemon.writeEntry("Timeout", 10);
        KConfigGroup(lock, QStringLiteral("Greeter")).writeEntry("Theme", QStringLiteral("breeze"));
        lock->sync();
        saveAccessibility(notes);
    } else if (section == QLatin1String("shortcuts")) {
        saveShortcuts(notes);
    } else if (section == QLatin1String("system")) {
        saveSystem(notes);
        // NTP exige permiso: intento honesto con aviso si no se puede.
        if (!runHelper(QStringLiteral("timedatectl"),
                       {QStringLiteral("set-ntp"), QStringLiteral("true")})) {
            notes << QStringLiteral("NTP necesita permiso de administrador.");
        }
    } else if (section == QLatin1String("updates")) {
        saveUpdates(notes);
    } else if (section == QLatin1String("network")) {
        // Sin ficheros propios: radios encendidos + redescubrir.
        if (m_nmcliAvailable) {
            if (runHelper(QStringLiteral("nmcli"), {QStringLiteral("radio"),
                                                    QStringLiteral("wifi"),
                                                    QStringLiteral("on")})) {
                m_wifiEnabled = true;
                Q_EMIT wifiEnabledChanged();
                refreshWifi();
            } else {
                notes << QStringLiteral("No se pudo encender el wifi.");
            }
        }
        if (m_bluetoothAvailable) {
            if (runHelper(QStringLiteral("bluetoothctl"), {QStringLiteral("power"),
                                                           QStringLiteral("on")})) {
                m_bluetoothPowered = true;
                Q_EMIT bluetoothPoweredChanged();
                refreshBluetooth();
            } else {
                notes << QStringLiteral("No se pudo encender el Bluetooth.");
            }
        }
    } else {
        setHelperStatus(QStringLiteral("Sección desconocida."));
        return;
    }
    setHelperStatus(notes.isEmpty() ? QStringLiteral("Sección restablecida a valores Nimbus.")
                                    : notes.join(QStringLiteral(" · ")));
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
    m_dailyCheck = false;
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
    Q_EMIT dailyCheckChanged();
    setNeedsSave(true);
    setRepresentsDefaults(true);
}

bool NimbusModule::installingUpdate() const
{
    return m_installProc != nullptr;
}

QString NimbusModule::installingPackage() const
{
    return m_installingPackage;
}

QString NimbusModule::installOutput() const
{
    return m_installOutput;
}

void NimbusModule::installUpdate(const QString &package)
{
    // Nombres de paquete Arch: letras, dígitos y .@_+- (sin espacios ni shell).
    static const QRegularExpression validPkg(QStringLiteral("^[A-Za-z0-9@._+-]+$"));
    if (package.isEmpty() || !validPkg.match(package).hasMatch() || m_installProc != nullptr) {
        return;
    }
    // Cadena: pkexec+pacman; sin pkexec, pamac; sin ninguno, aviso a Discover.
    QString program = QStandardPaths::findExecutable(QStringLiteral("pkexec"));
    QStringList args;
    if (!program.isEmpty()) {
        args = {QStringLiteral("pacman"), QStringLiteral("-S"), QStringLiteral("--noconfirm"),
                package};
    } else {
        program = QStandardPaths::findExecutable(QStringLiteral("pamac"));
        if (program.isEmpty()) {
            setHelperStatus(QStringLiteral("Sin instalador (abre Discover)."));
            return;
        }
        args = {QStringLiteral("install"), QStringLiteral("--no-confirm"), package};
    }
    m_installingPackage = package;
    m_installOutput.clear();
    Q_EMIT installingPackageChanged();
    Q_EMIT installOutputChanged();
    m_installProc = new QProcess(this);
    connect(m_installProc, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus) {
                bool ok = false;
                if (m_installProc != nullptr) {
                    const QString raw =
                        QString::fromUtf8(m_installProc->readAllStandardOutput())
                        + QString::fromUtf8(m_installProc->readAllStandardError());
                    m_installOutput = raw.right(2000);
                    ok = (exitCode == 0);
                    m_installProc->deleteLater();
                    m_installProc = nullptr;
                }
                m_installingPackage.clear();
                Q_EMIT installingUpdateChanged();
                Q_EMIT installingPackageChanged();
                Q_EMIT installOutputChanged();
                setHelperStatus(ok ? QStringLiteral("Instalado. Revisa la lista.")
                                   : QStringLiteral("Falló la instalación (mira la salida)."));
                if (ok) {
                    refreshUpdates();
                }
                Q_EMIT installFinished(ok);
            });
    m_installProc->setProgram(program);
    m_installProc->setArguments(args);
    m_installProc->start();
    Q_EMIT installingUpdateChanged();
    setHelperStatus(QStringLiteral("Instalando %1… (pedirá permiso)").arg(package));
}

bool NimbusModule::trySetHostName(const QString &name)
{
    static const QRegularExpression validHost(QStringLiteral("^[A-Za-z0-9-]{1,64}$"));
    if (!validHost.match(name).hasMatch()) {
        setHelperStatus(QStringLiteral("Nombre no válido (letras, dígitos y guiones)."));
        return false;
    }
    // hostnamectl usa polkit: en sesión real pide permiso; sin agente falla
    // sin cambiar nada.
    if (!runHelper(QStringLiteral("hostnamectl"), {QStringLiteral("set-hostname"), name}, 30000)) {
        setHelperStatus(QStringLiteral("Cambiar el equipo necesita permiso de administrador."));
        return false;
    }
    m_hostName = name;
    Q_EMIT hostNameChanged();
    return true;
}

bool NimbusModule::trySetLocale(const QString &locale)
{
    static const QRegularExpression validLoc(QStringLiteral("^[A-Za-z_]+(\\.[A-Za-z0-9-]+)?( .*)?$"));
    if (locale.isEmpty() || locale.contains(QLatin1Char(';')) || locale.contains(QLatin1Char('|'))
        || locale.contains(QLatin1Char('&'))) {
        setHelperStatus(QStringLiteral("Idioma no válido."));
        return false;
    }
    if (!validLoc.match(locale).hasMatch()) {
        setHelperStatus(QStringLiteral("Idioma no válido."));
        return false;
    }
    if (!runHelper(QStringLiteral("localectl"), {QStringLiteral("set-locale"),
                                                 QStringLiteral("LANG=") + locale}, 30000)) {
        setHelperStatus(QStringLiteral("Cambiar el idioma necesita permiso de administrador."));
        return false;
    }
    m_systemLocale = QStringLiteral("System Locale: LANG=") + locale;
    Q_EMIT systemLocaleChanged();
    return true;
}

#include "nimbusmodule.moc"
