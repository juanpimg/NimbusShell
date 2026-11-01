// aboutbackend.cpp — F10-T01. Ver cabecera.
#include "aboutbackend.h"
#include <QClipboard>
#include <QFile>
#include <QGuiApplication>
#include <QProcess>
#include <QRegularExpression>
#include <QTextStream>
#include <cstdlib>

namespace {
const char *kSimEnv = "NIMBUS_ABOUT_SIM";
bool simEnv()
{
    const char *v = std::getenv(kSimEnv);
    return v && QString::fromLocal8Bit(v) == QStringLiteral("1");
}
QString firstLine(const QString &s) { return s.split(u'\n').value(0).trimmed(); }
}

QString AboutBackend::runCmd(const QString &prog, const QStringList &args, int timeoutMs)
{
    QProcess p;
    p.start(prog, args);
    if (!p.waitForFinished(timeoutMs))
        return {};
    if (p.exitCode() != 0)
        return firstLine(QString::fromLocal8Bit(p.readAllStandardOutput() + p.readAllStandardError()));
    return firstLine(QString::fromLocal8Bit(p.readAllStandardOutput()));
}

AboutBackend::AboutBackend(QObject *parent) : QObject(parent), m_sim(simEnv()) { collect(); }

void AboutBackend::collect()
{
    if (m_sim) {
        m_kernel = QStringLiteral("6.0.0-sim");
        m_plasma = QStringLiteral("6.8 (sim)");
        m_qt = QStringLiteral("6.12 (sim)");
        m_kwin = QStringLiteral("6.8 (sim)");
        m_cpu = QStringLiteral("CPU simulada 8×");
        m_ram = QStringLiteral("16 GB (sim)");
        m_gpu = QStringLiteral("GPU simulada");
        return;
    }
    QFile kf(QStringLiteral("/proc/sys/kernel/osrelease"));
    if (kf.open(QIODevice::ReadOnly | QIODevice::Text))
        m_kernel = firstLine(QTextStream(&kf).readAll());
    if (m_kernel.isEmpty())
        m_kernel = QStringLiteral("desconocido");
    m_plasma = runCmd(QStringLiteral("plasmashell"), { QStringLiteral("--version") });
    if (m_plasma.isEmpty())
        m_plasma = QStringLiteral("Plasma (no detectado)");
    m_qt = runCmd(QStringLiteral("qmake6"), { QStringLiteral("-query"), QStringLiteral("QT_VERSION") });
    if (m_qt.isEmpty())
        m_qt = QString::fromLatin1(QT_VERSION_STR);
    m_kwin = runCmd(QStringLiteral("kwin_wayland"), { QStringLiteral("--version") });
    if (m_kwin.isEmpty())
        m_kwin = QStringLiteral("KWin (no detectado)");
    // CPU: primera "model name".
    QFile cf(QStringLiteral("/proc/cpuinfo"));
    if (cf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString txt = QTextStream(&cf).readAll();
        const auto m = QRegularExpression(QStringLiteral("model name\\s*:\\s*(.+)")).match(txt);
        m_cpu = m.hasMatch() ? m.captured(1).trimmed() : QStringLiteral("CPU desconocida");
    } else {
        m_cpu = QStringLiteral("CPU desconocida");
    }
    // RAM: MemTotal -> GB con 1 decimal.
    QFile mf(QStringLiteral("/proc/meminfo"));
    if (mf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString txt = QTextStream(&mf).readAll();
        const auto m = QRegularExpression(QStringLiteral("MemTotal:\\s*(\\d+)\\s*kB")).match(txt);
        if (m.hasMatch()) {
            const double gb = m.captured(1).toDouble() / 1024.0 / 1024.0;
            m_ram = QString::number(gb, 'f', 1) + QStringLiteral(" GB");
        } else {
            m_ram = QStringLiteral("desconocida");
        }
    } else {
        m_ram = QStringLiteral("desconocida");
    }
    // GPU: primera línea VGA/3D de lspci (mejor esfuerzo).
    const QString lspci = runCmd(QStringLiteral("sh"),
        { QStringLiteral("-c"), QStringLiteral("lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3-") }, 5000);
    m_gpu = lspci.isEmpty() ? QStringLiteral("GPU no detectada (instala pciutils)") : lspci.trimmed();
}

QString AboutBackend::credits() const
{
    return QStringLiteral("NimbusShell · Sequoia NPS · Inter · Klassy · Krema · Plasma (KDE)");
}

QString AboutBackend::infoText() const
{
    return QStringLiteral("NimbusShell %1\n%2\nNúcleo: %3\nPlasma: %4\nQt: %5\nKWin: %6\nCPU: %7\nRAM: %8\nGPU: %9\n%10")
        .arg(version(), osName(), m_kernel, m_plasma, m_qt, m_kwin, m_cpu, m_ram, m_gpu, credits());
}

void AboutBackend::copyInfo()
{
    if (QClipboard *cb = QGuiApplication::clipboard())
        cb->setText(infoText());
}

void AboutBackend::openHelp(const QString &tab)
{
    QString t = tab;
    if (t != QStringLiteral("guide") && t != QStringLiteral("shortcuts"))
        t = QStringLiteral("guide");
    QProcess::startDetached(QStringLiteral("nimbus-help"), { QStringLiteral("--tab"), t });
}
