// F8-T02/T04/T05 — probe headless del KCM: ejercita load()/save()/
// defaults() de NimbusModule con HOME temporal y vuelca el estado.
// Uso: save_probe [dump|appearance|a11y|shortcuts|defaults]
// Sale 0 siempre salvo crash; las aserciones las hace test-pages.sh con
// kreadconfig6/gsettings (canales reales).
#include "nimbusmodule.h"

#include <KPluginMetaData>
#include <QCoreApplication>
#include <QEventLoop>
#include <QTextStream>
#include <QTimer>

static void dump(NimbusModule &m)
{
    QTextStream out(stdout);
    auto boolean = [](bool v) { return v ? "true" : "false"; };
    out << "darkMode=" << boolean(m.darkMode()) << "\n";
    out << "accentColor=" << m.accentColor() << "\n";
    out << "wallpaperPath=" << m.wallpaperPath() << "\n";
    out << "dockIconSize=" << m.dockIconSize() << "\n";
    out << "dockZoomFactor=" << m.dockZoomFactor() << "\n";
    out << "dockAutohide=" << boolean(m.dockAutohide()) << "\n";
    out << "barHeight=" << m.barHeight() << "\n";
    out << "animationSpeed=" << m.animationSpeed() << "\n";
    out << "zoomEnabled=" << boolean(m.zoomEnabled()) << "\n";
    out << "invertColors=" << boolean(m.invertColors()) << "\n";
    out << "reduceMotion=" << boolean(m.reduceMotion()) << "\n";
    out << "reduceTransparency=" << boolean(m.reduceTransparency()) << "\n";
    out << "keyboardRepeat=" << boolean(m.keyboardRepeat()) << "\n";
    out << "repeatDelay=" << m.repeatDelay() << "\n";
    out << "repeatRate=" << m.repeatRate() << "\n";
    out << "screenReader=" << boolean(m.screenReader()) << "\n";
    out << "orcaInstalled=" << boolean(m.orcaInstalled()) << "\n";
    out << "cmdMode=" << boolean(m.cmdMode()) << "\n";
    out << "helperStatus=" << m.helperStatus() << "\n";
    out << "wifiAvailable=" << boolean(m.wifiAvailable()) << "\n";
    out << "wifiEnabled=" << boolean(m.wifiEnabled()) << "\n";
    out << "wifiSsid=" << m.wifiSsid() << "\n";
    out << "wifiCount=" << m.wifiNetworks().size() << "\n";
    out << "bluetoothAvailable=" << boolean(m.bluetoothAvailable()) << "\n";
    out << "bluetoothPowered=" << boolean(m.bluetoothPowered()) << "\n";
    out << "btCount=" << m.bluetoothDevices().size() << "\n";
    out << "printingAvailable=" << boolean(m.printingAvailable()) << "\n";
    out << "printerInfo=" << m.printerInfo().replace("\n", " / ") << "\n";
    out << "userCount=" << m.userList().size() << "\n";
    out << "currentUser=" << m.currentUser() << "\n";
    out << "hostName=" << m.hostName() << "\n";
    out << "timeZone=" << m.timeZone() << "\n";
    out << "ntpEnabled=" << boolean(m.ntpEnabled()) << "\n";
    out << "systemLocale=" << m.systemLocale() << "\n";
    out << "energyProfile=" << m.energyProfile() << "\n";
    out << "energyProfiles=" << m.energyProfiles().join(",") << "\n";
    out << "updatesAvailable=" << boolean(m.updatesAvailable()) << "\n";
    out << "updatesCount=" << m.updatesCount() << "\n";
    out << "updatesShown=" << m.updatesList().size() << "\n";
    out << "dailyCheck=" << boolean(m.dailyCheck()) << "\n";
    out << "discoverInstalled=" << boolean(m.discoverInstalled()) << "\n";
    out << "snapshotsAvailable=" << boolean(m.snapshotsAvailable()) << "\n";
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QString scenario = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QStringLiteral("dump");
    NimbusModule m(nullptr, KPluginMetaData());
    m.load();
    if (scenario == QStringLiteral("appearance")) {
        m.setDarkMode(false);
        m.setAccentColor(QStringLiteral("#FF9500"));
        m.setWallpaperPath(QStringLiteral("/tmp/nimbus-wall.jpg"));
        m.setDockIconSize(64);
        m.setDockZoomFactor(1.2);
        m.setDockAutohide(true);
        m.setBarHeight(32);
        m.setAnimationSpeed(2);
        m.save();
    } else if (scenario == QStringLiteral("a11y")) {
        m.setZoomEnabled(true);
        m.setInvertColors(true);
        m.setReduceMotion(true);
        m.setReduceTransparency(true);
        m.setKeyboardRepeat(true);
        m.setRepeatDelay(300);
        m.setRepeatRate(30);
        m.setScreenReader(true);
        m.save();
    } else if (scenario == QStringLiteral("shortcuts-ctrl")) {
        m.setCmdMode(false);
        m.save();
    } else if (scenario == QStringLiteral("shortcuts-meta")) {
        m.setCmdMode(true);
        m.save();
    } else if (scenario == QStringLiteral("defaults")) {
        m.defaults();
        m.save();
    } else if (scenario == QStringLiteral("network")) {
        // Solo lectura (no tocar radios del host); load() ya escaneó.
        m.refreshWifi();
        m.refreshBluetooth();
    } else if (scenario == QStringLiteral("system")) {
        // Energía: cambio benigno y reversible (se restaura al final).
        const QString original = m.energyProfile();
        if (!m.energyProfiles().isEmpty()) {
            const QString target =
                m.energyProfiles().contains(QStringLiteral("balanced"))
                    ? QStringLiteral("balanced")
                    : m.energyProfiles().first();
            m.setEnergyProfile(target);
            m.refreshSystem();
            QTextStream(stdout) << "energyRoundtrip=" << m.energyProfile() << "\n";
            if (!original.isEmpty() && original != target) {
                m.setEnergyProfile(original);
            }
        }
        m.refreshSystem();
    } else if (scenario == QStringLiteral("updates")) {
        if (m.updatesAvailable()) {
            QEventLoop loop;
            QObject::connect(&m, &NimbusModule::updatesFinished, &loop, &QEventLoop::quit);
            QTimer::singleShot(150000, &loop, &QEventLoop::quit);
            m.refreshUpdates();
            loop.exec();
        }
    } else if (scenario == QStringLiteral("schedule-on")) {
        m.setDailyCheck(true);
        m.save();
    } else if (scenario == QStringLiteral("schedule-off")) {
        // Parte del mismo HOME que schedule-on: verifica borrado.
        m.load();
        QTextStream(stdout) << "dailyCheckLoaded=" << (m.dailyCheck() ? "true" : "false") << "\n";
        m.setDailyCheck(false);
        m.save();
    } else if (scenario == QStringLiteral("persist")) {
        // Escritura + relectura: prueba persistencia real en ficheros.
        m.setDarkMode(false);
        m.setDockIconSize(72);
        m.setZoomEnabled(true);
        m.setRepeatDelay(250);
        m.save();
        m.load();
    } else if (scenario == QStringLiteral("reset-appearance")) {
        m.setDarkMode(false);
        m.setAccentColor(QStringLiteral("#FF0000"));
        m.setDockIconSize(72);
        m.setBarHeight(48);
        m.save();
        m.resetSection(QStringLiteral("appearance"));
    } else if (scenario == QStringLiteral("reset-a11y")) {
        m.setZoomEnabled(true);
        m.setInvertColors(true);
        m.setReduceMotion(true);
        m.setReduceTransparency(true);
        m.setRepeatDelay(200);
        m.save();
        m.resetSection(QStringLiteral("accessibility"));
    } else if (scenario == QStringLiteral("reset-shortcuts")) {
        m.setCmdMode(false);
        m.save();
        m.resetSection(QStringLiteral("shortcuts"));
    } else if (scenario == QStringLiteral("reset-system")) {
        const QString original = m.energyProfile();
        if (!m.energyProfiles().isEmpty()) {
            const QString target =
                m.energyProfiles().contains(QStringLiteral("power-saver"))
                    ? QStringLiteral("power-saver")
                    : m.energyProfiles().first();
            m.setEnergyProfile(target);
            m.resetSection(QStringLiteral("system"));
            QTextStream(stdout) << "energyAfterReset=" << m.energyProfile() << "\n";
            if (!original.isEmpty() && original != m.energyProfile()) {
                m.setEnergyProfile(original);
            }
        }
    } else if (scenario == QStringLiteral("reset-updates")) {
        m.setDailyCheck(true);
        m.save();
        m.resetSection(QStringLiteral("updates"));
    } else if (scenario == QStringLiteral("reset-network")) {
        m.resetSection(QStringLiteral("network"));
    }
    dump(m);
    return 0;
}
