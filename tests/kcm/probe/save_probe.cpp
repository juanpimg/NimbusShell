// F8-T02/T04/T05 — probe headless del KCM: ejercita load()/save()/
// defaults() de NimbusModule con HOME temporal y vuelca el estado.
// Uso: save_probe [dump|appearance|a11y|shortcuts|defaults]
// Sale 0 siempre salvo crash; las aserciones las hace test-pages.sh con
// kreadconfig6/gsettings (canales reales).
#include "nimbusmodule.h"

#include <KPluginMetaData>
#include <QCoreApplication>
#include <QTextStream>

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
    }
    dump(m);
    return 0;
}
