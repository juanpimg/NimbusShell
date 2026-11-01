// nimbus-missioncontrol — overlay Mission Control/Spaces (F7 R-MC-CUSTOM).
// Flags: --demo (datos falsos), --shot <png> (captura propia tras pintar),
//   --reduce-motion (fade 150ms en vez de slide/zoom 450ms).
#include <QElapsedTimer>
#include <QEventLoop>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <QWindow>
#include <QtDBus/QDBusConnection>
#include <cstdio>
#include <unistd.h>

#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>

#include "kwinbackend.h"

class Toggle : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nimbus.MissionControl")
public:
    explicit Toggle(QWindow *w, KWinBackend *b, QObject *parent = nullptr)
        : QObject(parent), m_win(w), m_backend(b) {}
public Q_SLOTS:
    void toggle()
    {
        m_win->setVisible(!m_win->isVisible());
        if (m_win->isVisible()) {
            m_backend->refresh();
            m_win->requestActivate();
        }
    }
    void show() { m_win->setVisible(true); m_backend->refresh(); m_win->requestActivate(); }
    void hide() { m_win->setVisible(false); }
    void refresh() { m_backend->refresh(); }
    void pushWindows(const QString &json) { m_backend->pushWindows(json); }
    void pushState(const QString &json) { m_backend->pushState(json); }
    int windowCount() const { return m_backend->windows().size(); }
    int desktopCount() const { return m_backend->desktops().size(); }
    int openLatencyMs() const { return m_backend->openLatencyMs(); }
    QString activateFirst() { return m_backend->activateFirst(); }
    QString moveFirstTo(int deskIndex) { return m_backend->moveFirstTo(deskIndex); }
    void createSpace() { m_backend->createSpace(); }
    void ensureSpaces(int n) { m_backend->ensureSpaces(n); }
    void requestThumbs() { m_backend->requestThumbs(); }
    QString thumbLog() const { return m_backend->thumbLog(); }
    void replayIntro() { m_backend->replayIntro(); }
    void setReduceMotion(bool v) { m_backend->setReduceMotion(v); }
    void showDesktop(bool show) { m_backend->showDesktop(show); }
    void toggleExpose() { m_backend->toggleExpose(); }
    void setCurrentDesktopByIndex(int i) { m_backend->setCurrentDesktopByIndex(i); }
    void setCurrentDesktopById(const QString &id) { m_backend->setCurrentDesktopById(id); }
    // Captura bajo demanda (fases del test nested).
    bool grabShot(const QString &path)
    {
        auto *qw = qobject_cast<QQuickWindow *>(m_win);
        if (!qw)
            return false;
        QImage img = qw->grabWindow();
        return !img.isNull() && img.save(path);
    }
    // F7-T08: info de pantallas (count, primaria, geometría MC).
    QString screenInfo()
    {
        const QList<QScreen *> ss = QGuiApplication::screens();
        QStringList parts;
        for (QScreen *s : ss)
            parts << QStringLiteral("%1:%2x%3%4")
                         .arg(s->name(),
                              QString::number(s->geometry().width()),
                              QString::number(s->geometry().height()),
                              s == QGuiApplication::primaryScreen()
                                  ? QStringLiteral("(prim)")
                                  : QString());
        const QRect g = m_win->geometry();
        return QStringLiteral("count=%1 [%2] mc=%3x%4@%5,%6")
            .arg(ss.size())
            .arg(parts.join(QStringLiteral(" ")))
            .arg(g.width())
            .arg(g.height())
            .arg(g.x())
            .arg(g.y());
    }
    // F7-T10: invoca la misma ruta que los Shortcuts de teclado QML.
    QString selftestKey(const QString &name)
    {
        auto *qw = qobject_cast<QQuickWindow *>(m_win);
        if (!qw)
            return QStringLiteral("sin-ventana");
        const char *fn = nullptr;
        if (name == QStringLiteral("Enter"))
            fn = "uiEnter";
        else if (name == QStringLiteral("Tab"))
            fn = "uiExpose";
        else if (name == QStringLiteral("Left"))
            fn = "uiLeft";
        else if (name == QStringLiteral("Right"))
            fn = "uiRight";
        else if (name == QStringLiteral("Escape"))
            fn = "uiEsc";
        else
            return QStringLiteral("tecla-desconocida");
        bool ok = QMetaObject::invokeMethod(qw, fn);
        return ok ? QStringLiteral("ok:") + name : QStringLiteral("fallo-invoke:") + name;
    }
    // F7-T10: estado observable para la matriz de aceptación.
    QString uiState()
    {
        auto *qw = qobject_cast<QQuickWindow *>(m_win);
        if (!qw)
            return QStringLiteral("sin-ventana");
        QVariant ret;
        bool ok = QMetaObject::invokeMethod(qw, "uiState",
                                            Q_RETURN_ARG(QVariant, ret));
        return ok ? ret.toString() : QStringLiteral("fallo-invoke");
    }
    bool isVisible() const { return m_win->isVisible(); }
    int fpsProbe()
    {
        int frames = 0;
        auto *qw = qobject_cast<QQuickWindow *>(m_win);
        if (!qw)
            return -1;
        QMetaObject::Connection c =
            QObject::connect(qw, &QQuickWindow::frameSwapped, [&frames]() { ++frames; });
        QEventLoop loop;
        QTimer t;
        t.setSingleShot(true);
        QObject::connect(&t, &QTimer::timeout, &loop, &QEventLoop::quit);
        QElapsedTimer e;
        e.start();
        t.start(1200);
        loop.exec();
        QObject::disconnect(c);
        const int ms = int(e.elapsed());
        return ms > 0 ? frames * 1000 / ms : 0;
    }
private:
    QWindow *m_win = nullptr;
    KWinBackend *m_backend = nullptr;
};

int main(int argc, char *argv[])
{
    fprintf(stderr, "MC-MAIN-ENTER pid=%d\n", (int)getpid());
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    LayerShellQt::Shell::useLayerShell();
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-missioncontrol"));
    app.setOrganizationName(QStringLiteral("nimbus"));

    qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &,
                              const QString &m) {
        fprintf(stderr, "nimbus-mc[%d]: %s\n", static_cast<int>(t),
                m.toUtf8().constData());
    });

    bool demo = false, reduceMotion = false;
    QString shotPath;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo"))
            demo = true;
        else if (a == QStringLiteral("--reduce-motion"))
            reduceMotion = true;
        else if (a == QStringLiteral("--shot") && i + 1 < argc)
            shotPath = QString::fromLocal8Bit(argv[++i]);
    }

    KWinBackend backend(demo);
    backend.setReduceMotion(reduceMotion);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &w) {
                         for (const auto &e : w)
                             qWarning().noquote() << e.toString();
                     });
    QElapsedTimer openT;
    openT.start();
    engine.load(QStringLiteral("qrc:/qml/MissionControl.qml"));
    if (engine.rootObjects().isEmpty()) {
        fprintf(stderr, "nimbus-mc: FALLO al cargar qrc:/qml/MissionControl.qml\n");
        return 1;
    }
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        qWarning("nimbus-mc: root no es Window");
        return 1;
    }

    // Fullscreen sobre todo, sin zona exclusiva, teclado solo si visible.
    // F7-T08: sigue a la primaria si cambia el layout (R-MC-DISPLAY).
    auto refitPrimary = [win]() {
        if (QScreen *sc = QGuiApplication::primaryScreen())
            win->setGeometry(sc->geometry());
    };
    refitPrimary();
    QObject::connect(&app, &QGuiApplication::primaryScreenChanged,
                     win, [refitPrimary](QScreen *) { refitPrimary(); });
    if (auto *ls = LayerShellQt::Window::get(win)) {
        ls->setLayer(LayerShellQt::Window::LayerOverlay);
        ls->setExclusiveZone(-1);
        ls->setKeyboardInteractivity(
            LayerShellQt::Window::KeyboardInteractivityExclusive);
        ls->setScope(QStringLiteral("nimbus-missioncontrol"));
    }
    QObject::connect(win, &QWindow::visibleChanged, win, [win](bool v) {
        if (auto *ls = LayerShellQt::Window::get(win)) {
            ls->setKeyboardInteractivity(v
                ? LayerShellQt::Window::KeyboardInteractivityExclusive
                : LayerShellQt::Window::KeyboardInteractivityNone);
        }
    });

    Toggle toggler(win, &backend);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.nimbus.MissionControl")))
        qWarning("nimbus-mc: sin servicio DBus (otra instancia?)");
    else
        bus.registerObject(QStringLiteral("/MC"), &toggler,
                           QDBusConnection::ExportAllSlots);

    qInfo().noquote() << QStringLiteral("nimbus-mc: open_ms=%1 demo=%2 rm=%3")
                             .arg(openT.elapsed()).arg(demo).arg(reduceMotion);

    if (!shotPath.isEmpty()) {
        QTimer::singleShot(2500, win, [win, shotPath]() {
            if (auto *img = new QImage(win->grabWindow()); !img->isNull())
                img->save(shotPath);
            else
                qWarning("nimbus-mc: grabWindow vacío");
        });
    }
    backend.refresh();
    win->setVisible(true);
    win->requestActivate();
    return app.exec();
}

#include "main.moc"
